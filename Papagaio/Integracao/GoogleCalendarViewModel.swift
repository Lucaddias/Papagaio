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
    private(set) var reunioes: [ReuniaoExterna] = []
    private(set) var carregandoReunioes = false
    private(set) var importando = false
    private(set) var falhaDeImportacao: String?

    var aoNotificar: (@MainActor (_ titulo: String, _ mensagem: String, _ tipo: NotificacaoDoApp.Tipo) -> Void)?

    private let cofre = CofreDeTokens(servico: "papagaio:google-calendar")
    private var sessao: SessaoOAuthGoogle?
    private var fonte: FonteGoogleCalendarAPI?
    private let registro = Logger(subsystem: "Papagaio", category: "GoogleCalendar")
    private var timerDeSincronizacao: Task<Void, Never>?

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
            estado = .conectado(conta)
            registro.info("Conectado: \(conta.email, privacy: .public)")
            await carregarReunioes()
            await importarTodas(biblioteca: biblioteca)
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
        reunioes = []
        falhaDeImportacao = nil
        estado = .desconectado
    }

    func recarregar() async {
        guard estado.conectado else { return }
        await carregarReunioes()
    }

    /// Obtém os detalhes de uma reunião específica (para importar notas, etc.)
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
                        // Nota: importarTodas precisa da biblioteca — será chamado pelo ContentView via observer
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
            reunioes = try await fonte.listarReunioes()
            registro.info("\(self.reunioes.count) reuniões carregadas do Google Calendar")
        } catch {
            falhaDeImportacao = ErroDaConexao.descricao(do: error)
            registro.error("Falha ao carregar reuniões: \(ErroDaConexao.descricao(do: error), privacy: .public)")
        }
    }

    /// Importa todas as reuniões carregadas atualmente para a biblioteca.
    /// Chamado automaticamente após conectar e a cada sincronização (15 min).
    func importarTodas(biblioteca: Biblioteca) async {
        guard let fonte, estado.conectado, !importando, !self.reunioes.isEmpty else { return }
        importando = true
        falhaDeImportacao = nil
        defer { importando = false }
        registro.info("Importando automaticamente \(self.reunioes.count) reunião(ões) do Google Calendar")

        var salvas = 0
        for reuniao in self.reunioes {
            do {
                let detalhe = try await fonte.obterReuniao(id: reuniao.id, incluirTranscricao: false)
                if await biblioteca.registrarExterna(detalhe, identificador: fonte.identificador) != nil {
                    salvas += 1
                }
            } catch {
                falhaDeImportacao = "\(reuniao.titulo): \(ErroDaConexao.descricao(do: error))"
            }
        }
        if salvas > 0 {
            registro.info("\(salvas) reunião(ões) importada(s) automaticamente do Google Calendar")
            aoNotificar?(
                "Reuniões sincronizadas",
                "\(salvas) reunião(ões) do Google Calendar adicionadas à biblioteca.",
                .sucesso
            )
        }
    }

    func importar(_ ids: Set<String>, biblioteca: Biblioteca) async -> Int {
        guard let fonte, estado.conectado, !importando else { return 0 }
        importando = true
        falhaDeImportacao = nil
        defer { importando = false }
        registro.info("Importando \(ids.count) reunião(ns) do Google Calendar")

        var salvas = 0
        for id in ids {
            guard let reuniao = reunioes.first(where: { $0.id == id }) else { continue }
            do {
                let detalhe = try await fonte.obterReuniao(id: id, incluirTranscricao: false)
                if await biblioteca.registrarExterna(detalhe, identificador: fonte.identificador) != nil {
                    salvas += 1
                }
            } catch {
                falhaDeImportacao = "\(reuniao.titulo): \(ErroDaConexao.descricao(do: error))"
            }
        }
        if salvas > 0 {
            registro.info("\(salvas) reunião(ns) importada(s) do Google Calendar")
            aoNotificar?(
                "Reuniões importadas",
                "\(salvas) reunião(ns) do Google Calendar na biblioteca.",
                .sucesso
            )
        }
        return salvas
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