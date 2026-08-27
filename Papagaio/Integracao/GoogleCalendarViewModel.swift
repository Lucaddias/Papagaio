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
    private var tarefaDeConexao: Task<Void, Never>?
    private var idDaTarefaDeConexao: UUID?
    private var tarefasDeImportacao: [UUID: Task<Arquivo?, Never>] = [:]
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
        guard tarefaDeConexao == nil, !estado.conectado, !(estado == .conectando) else { return }
        let id = UUID()
        let tarefa = Task { @MainActor [weak self, weak biblioteca] in
            guard let self, let biblioteca else { return }
            await self.executarConexao(biblioteca: biblioteca)
        }
        idDaTarefaDeConexao = id
        tarefaDeConexao = tarefa
        await tarefa.value
        if idDaTarefaDeConexao == id {
            tarefaDeConexao = nil
            idDaTarefaDeConexao = nil
        }
    }

    private func executarConexao(biblioteca: Biblioteca) async {
        estado = .conectando
        registro.info("Iniciando conexão com o Google Calendar")

        let sessao = SessaoOAuthGoogle(cofre: cofre)
        self.sessao = sessao

        do {
            let fonte = FonteGoogleCalendarAPI { forcar in
                try await sessao.tokenDeAcesso(forcandoRenovacao: forcar)
            }
            let conta = try await fonte.conta()
            self.fonte = fonte
            self.bibliotecaRef = biblioteca
            estado = .conectado(conta)
            registro.info("Conta Google Calendar conectada")
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

    /// Interrompe o estado local sem depender da rede. A cascata de exclusão
    /// apaga o Keychain em seguida, inclusive quando a reconexão havia falhado
    /// antes de criar uma sessão em memória.
    func encerrarLocalmenteParaExclusaoDoPerfil() async {
        let timer = timerDeSincronizacao
        timer?.cancel()
        timerDeSincronizacao = nil

        let conexao = tarefaDeConexao
        conexao?.cancel()
        let importacoes = Array(tarefasDeImportacao.values)
        importacoes.forEach { $0.cancel() }
        if let conexao { await conexao.value }
        for importacao in importacoes { _ = await importacao.value }

        tarefaDeConexao = nil
        idDaTarefaDeConexao = nil
        tarefasDeImportacao.removeAll()
        sessao = nil
        fonte = nil
        bibliotecaRef = nil
        reunioesPendentes = []
        carregandoReunioes = false
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
        let id = UUID()
        let tarefa = Task { @MainActor [weak self, weak biblioteca] () -> Arquivo? in
            guard let self, let biblioteca else { return nil }
            return await self.executarImportacaoDeAudio(
                pendente,
                audioURL: audioURL,
                biblioteca: biblioteca
            )
        }
        tarefasDeImportacao[id] = tarefa
        let arquivo = await tarefa.value
        tarefasDeImportacao[id] = nil
        return arquivo
    }

    private func executarImportacaoDeAudio(
        _ pendente: ReuniaoPendenteCalendar,
        audioURL: URL,
        biblioteca: Biblioteca
    ) async -> Arquivo? {
        guard !Task.isCancelled else { return nil }
        let arquivo = await biblioteca.criarArquivoDeReuniaoPendente(
            pendente,
            audioURL: audioURL
        )
        if arquivo != nil {
            reunioesPendentes.removeAll { $0.id == pendente.id }
        }
        return arquivo
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
