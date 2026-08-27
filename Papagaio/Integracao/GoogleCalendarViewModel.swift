import Foundation
import Observation
import os
import PapagaioCore

enum EstadoDaConexaoGoogleCalendar: Equatable {
    case desconectado
    case conectando
    case conectado(ContaExterna)
    case falhou(String)

    var conectado: Bool {
        if case .conectado = self { return true }
        return false
    }
}

@MainActor
@Observable
final class GoogleCalendarViewModel {
    private(set) var estado: EstadoDaConexaoGoogleCalendar = .desconectado
    private(set) var reunioesPendentes: [ReuniaoPendenteCalendar] = []
    private(set) var carregandoReunioes = false
    private(set) var falhaDeImportacao: String?

    var aoNotificar: (@MainActor (_ titulo: String, _ mensagem: String, _ tipo: NotificacaoDoApp.Tipo) -> Void)?

    private let cofre = CofreDeTokens(servico: "papagaio:google-calendar")
    private var sessao: SessaoOAuthGoogle?
    private var fonte: FonteGoogleCalendarAPI?
    private let registro = Logger(subsystem: "Papagaio", category: "GoogleCalendar")
    private var timerDeSincronizacao: Task<Void, Never>?
    private weak var bibliotecaRef: Biblioteca?

    /// Reconexão automática só é legítima quando já houve consentimento e há
    /// uma credencial persistida. Ter Client ID no build apenas habilita o
    /// botão de conexão; não autoriza rede nem abertura de navegador.
    var temAutorizacaoPersistida: Bool {
        let refresh = cofre.carregar(conta: "refresh_token")
        let acesso = cofre.carregar(conta: "access_token")
        return refresh?.isEmpty == false || acesso?.isEmpty == false
    }

    func conectar(biblioteca: Biblioteca) async {
        guard !estado.conectado, !(estado == .conectando) else { return }
        estado = .conectando
        registro.info("Iniciando conexão com o Google Calendar")

        let sessao = SessaoOAuthGoogle(
            cofre: cofre,
            apresentador: ApresentadorDeSessaoDeAutorizacao()
        )
        self.sessao = sessao

        do {
            let fonte = FonteGoogleCalendarAPI { forcar in
                try await sessao.tokenDeAcesso(forcandoRenovacao: forcar)
            }
            let conta = try await fonte.conta()
            self.fonte = fonte
            self.bibliotecaRef = biblioteca
            estado = .conectado(conta)
            registro.info("Conectado: \(conta.email, privacy: .public)")
            await carregarReunioes()
            iniciarTimerSincronizacao()
        } catch {
            self.sessao = nil
            self.fonte = nil
            estado = .falhou(ErroDaConexao.descricao(do: error))
            registro.error("Conexão Google Calendar falhou: \(ErroDaConexao.descricao(do: error), privacy: .public)")
        }
    }

    func desconectar() async {
        timerDeSincronizacao?.cancel()
        timerDeSincronizacao = nil
        await sessao?.sair()
        sessao = nil
        fonte = nil
        bibliotecaRef = nil
        reunioesPendentes = []
        falhaDeImportacao = nil
        estado = .desconectado
    }

    func recarregar() async {
        guard estado.conectado else { return }
        await carregarReunioes()
    }

    func obterDetalhesReuniao(id: String) async throws -> ReuniaoExterna? {
        guard let fonte, estado.conectado else { return nil }
        return try await fonte.obterReuniao(id: id, incluirTranscricao: false)
    }

    private func iniciarTimerSincronizacao() {
        timerDeSincronizacao?.cancel()
        timerDeSincronizacao = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                do {
                    try await Task.sleep(for: .seconds(15 * 60))
                    guard let self else { break }
                    if self.estado.conectado {
                        await self.carregarReunioes()
                    }
                } catch {
                    break
                }
            }
        }
    }

    private func carregarReunioes() async {
        guard let fonte else { return }
        carregandoReunioes = true
        defer { carregandoReunioes = false }
        do {
            let eventos = try await fonte.listarEventos()
            let agora = Date()
            let limite24h = agora.addingTimeInterval(24 * 3600)

            let jaConvertidos: Set<String> = {
                guard let bib = bibliotecaRef else { return [] }
                let idsArquivos = bib.arquivos.compactMap(\.idExterno)
                let idsLixeira = bib.arquivosNaLixeira.compactMap(\.idExterno)
                let idsPendentesLixeira = bib.reunioesPendentesNaLixeira.map(\.idExterno)
                return Set(idsArquivos + idsLixeira + idsPendentesLixeira)
            }()

            let pendentes = eventos
                .filter { evento in
                    // Só eventos futuros (até 24h) e que não expiraram
                    guard evento.dataHora <= limite24h,
                          evento.dataHora.addingTimeInterval(12 * 3600) > Date()
                    else { return false }
                    // Já virou conversa ou foi ignorada: não reaparece
                    if jaConvertidos.contains("google-calendar-api:\(evento.id)") { return false }
                    return true
                }
                .map { ReuniaoPendenteCalendar(
                    id: $0.id,
                    titulo: $0.titulo,
                    dataHora: $0.dataHora,
                    participantes: $0.participantes,
                    descricao: $0.descricao,
                    idExterno: "google-calendar-api:\($0.id)"
                ) }
                .sorted { $0.dataHora < $1.dataHora }

            self.reunioesPendentes = pendentes
            registro.info("\(pendentes.count) reuniões pendentes carregadas do Google Calendar")
        } catch {
            falhaDeImportacao = ErroDaConexao.descricao(do: error)
            registro.error("Falha ao carregar reuniões: \(ErroDaConexao.descricao(do: error), privacy: .public)")
        }
    }

    /// Importa um arquivo de áudio local para uma reunião pendente e cria o
    /// Arquivo definitivo na biblioteca (com transcrição na fila). Não exige
    /// conexão: a pendente já está em memória.
    @discardableResult
    func importarAudioParaReuniao(_ pendente: ReuniaoPendenteCalendar, audioURL: URL, biblioteca: Biblioteca) async -> Arquivo? {
        do {
            let arquivo = try await biblioteca.criarArquivoDeReuniaoPendente(pendente, audioURL: audioURL)
            if arquivo != nil {
                reunioesPendentes.removeAll { $0.id == pendente.id }
            }
            return arquivo
        } catch {
            falhaDeImportacao = "\(pendente.titulo): \(ErroDaConexao.descricao(do: error))"
            return nil
        }
    }

    func ignorarPendente(_ pendente: ReuniaoPendenteCalendar) {
        reunioesPendentes.removeAll { $0.id == pendente.id }
    }

    private enum ErroDaConexao {
        static func descricao(do erro: any Error) -> String {
            if let localizado = erro as? any LocalizedError,
               let mensagem = localizado.errorDescription {
                return mensagem
            }
            return erro.localizedDescription
        }
    }
}
