import CryptoKit
import Foundation
import Testing
@testable import PapagaioCore

// Testes da camada de Integracao: OAuth (PKCE, metadados, URLs) e o
// mapeador Granola. O fluxo de rede/persistência real é exercitado pela CLI
// (`papagaio-eval granola`) — aqui ficam as partes puras, sem servidor.

@Suite("AutenticacaoOAuth — PKCE e URLs")
struct AutenticacaoOAuthTests {
    @Test("base64url remove padding e troca +/ por -_")
    func base64urlPadroes() {
        #expect(Data("foobar".utf8).base64URLSemPadding == "Zm9vYmFy")
        #expect(Data([0xFB, 0xFF, 0xBF]).base64URLSemPadding == "-_-_")
    }

    @Test("verificador tem 43 caracteres do alfabeto seguro e desafio é o SHA-256")
    func pkceGeraParValido() {
        let (verificador, desafio) = AutenticacaoOAuth.novoDesafioPKCE()
        #expect(verificador.count == 43)
        #expect(desafio.count == 43)
        let alfabeto = Set("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_")
        #expect(verificador.allSatisfy { alfabeto.contains($0) })
        let esperado = Data(SHA256.hash(data: Data(verificador.utf8))).base64URLSemPadding
        #expect(desafio == esperado)
    }

    @Test("URL dos metadados cai no .well-known acima da raiz do servidor")
    func urlDosMetadados() {
        #expect(
            AutenticacaoOAuth.urlDosMetadados(servidorMCP: URL(string: "https://mcp.granola.ai/mcp")!)
                == URL(string: "https://mcp.granola.ai/.well-known/oauth-authorization-server")
        )
        #expect(
            AutenticacaoOAuth.urlDosMetadados(servidorMCP: URL(string: "https://exemplo.com/root/mcp")!)
                == URL(string: "https://exemplo.com/root/.well-known/oauth-authorization-server")
        )
    }

    @Test("URL de autorização leva client_id, PKCE S256 e state — sem scope quando não há")
    func urlDeAutorizacaoSemEscopo() throws {
        let metadados = MetadadosDeAutenticacao(
            emissor: "https://mcp.granola.ai",
            autorizacaoEndpoint: URL(string: "https://mcp.granola.ai/oauth/authorize")!,
            tokenEndpoint: URL(string: "https://mcp.granola.ai/oauth/token")!,
            registroEndpoint: nil,
            escoposSuportados: nil
        )
        let cliente = ClienteRegistrado(
            id: "cliente-123",
            segredo: nil,
            redirecionamento: URL(string: "papagaio://oauth")!
        )
        let url = try AutenticacaoOAuth.urlDeAutorizacao(
            metadados,
            cliente: cliente,
            desafioPKCE: "desafio-xyz",
            estado: "estado-abc",
            escopos: nil
        )
        let itens = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
        func valor(_ nome: String) -> String? {
            itens.first { $0.name == nome }?.value
        }
        #expect(valor("response_type") == "code")
        #expect(valor("client_id") == "cliente-123")
        #expect(valor("redirect_uri") == "papagaio://oauth")
        #expect(valor("code_challenge") == "desafio-xyz")
        #expect(valor("code_challenge_method") == "S256")
        #expect(valor("state") == "estado-abc")
        #expect(valor("scope") == nil)
    }

    @Test("URL de autorização inclui scope quando existente e falha sem endpoint")
    func urlDeAutorizacaoComEscopo() throws {
        let metadados = MetadadosDeAutenticacao(
            emissor: "https://mcp.granola.ai",
            autorizacaoEndpoint: URL(string: "https://mcp.granola.ai/oauth/authorize")!,
            tokenEndpoint: nil,
            registroEndpoint: nil,
            escoposSuportados: ["notes", "meetings"]
        )
        let cliente = ClienteRegistrado(
            id: "cliente-123",
            segredo: nil,
            redirecionamento: URL(string: "papagaio://oauth")!
        )
        let url = try AutenticacaoOAuth.urlDeAutorizacao(
            metadados,
            cliente: cliente,
            desafioPKCE: "desafio-xyz",
            estado: "estado-abc",
            escopos: nil
        )
        let itens = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
        #expect(itens.first { $0.name == "scope" }?.value == "notes meetings")

        let semEndpoint = MetadadosDeAutenticacao(
            emissor: nil,
            autorizacaoEndpoint: nil,
            tokenEndpoint: nil,
            registroEndpoint: nil,
            escoposSuportados: nil
        )
        #expect(throws: ErroOAuth.semEndpointAutorizacao) {
            _ = try AutenticacaoOAuth.urlDeAutorizacao(
                semEndpoint,
                cliente: cliente,
                desafioPKCE: "d",
                estado: "e",
                escopos: nil
            )
        }
    }

    @Test("Metadados decodificam do JSON público do servidor, com campos opcionais")
    func decodificacaoDeMetadados() throws {
        let json = """
        {
          "issuer": "https://mcp.granola.ai",
          "authorization_endpoint": "https://mcp.granola.ai/oauth/authorize",
          "token_endpoint": "https://mcp.granola.ai/oauth/token",
          "registration_endpoint": "https://mcp.granola.ai/oauth/register",
          "scopes_supported": ["notes", "meetings"]
        }
        """.data(using: .utf8)!
        let metadados = try JSONDecoder().decode(MetadadosDeAutenticacao.self, from: json)
        #expect(metadados.emissor == "https://mcp.granola.ai")
        #expect(metadados.registroEndpoint?.absoluteString == "https://mcp.granola.ai/oauth/register")
        #expect(metadados.escoposSuportados == ["notes", "meetings"])

        let minimo = """
        {"authorization_endpoint": "https://mcp.granola.ai/oauth/authorize"}
        """.data(using: .utf8)!
        let soEndpoint = try JSONDecoder().decode(MetadadosDeAutenticacao.self, from: minimo)
        #expect(soEndpoint.tokenEndpoint == nil)
        #expect(soEndpoint.escoposSuportados == nil)
    }

    @Test("CredenciaisOAuth sabe quando o token expirou, com folga de segurança")
    func validadeDeCredenciais() {
        var validas = CredenciaisOAuth(tokenDeAcesso: "x", expiraEm: Date().addingTimeInterval(60))
        #expect(validas.aindaValido())
        validas.expiraEm = Date().addingTimeInterval(10)
        #expect(!validas.aindaValido())
        #expect(!CredenciaisOAuth(tokenDeAcesso: "x").aindaValido())
    }
}

@Suite("MapeadorGranola — JSON do servidor para o domínio")
struct MapeadorGranolaTests {
    private let mapeador = MapeadorGranola()
    private let iso = ISO8601DateFormatter()

    /// Constrói a árvore `ValorJSON` a partir de JSON — como o `ClienteMCP`
    /// entrega para o mapeador.
    private func json(_ string: String) -> ValorJSON {
        let dados = Data(string.utf8)
        let qualquer = try! JSONSerialization.jsonObject(with: dados)
        return ValorJSON(de: qualquer)!
    }

    @Test("conta lê email e workspace")
    func mapeiaConta() throws {
        let conta = try mapeador.conta(de: json("""
        {"email": "ana@granola.ai", "workspace": "Acme"}
        """))
        #expect(conta.email == "ana@granola.ai")
        #expect(conta.workspace == "Acme")
    }

    @Test("lista de reuniões vira ReuniaoExterna com participantes por nome")
    func mapeiaLista() throws {
        let reunioes = try mapeador.lista(de: json("""
        {
          "meetings": [
            {
              "meeting_id": "a1b2",
              "meeting_title": "Planejamento Q3",
              "meeting_date": "2026-08-19T10:00:00Z",
              "attendees": [
                {"name": "Ana", "email": "ana@granola.ai"},
                {"name": "Bia", "email": "bia@granola.ai"}
              ]
            },
            {
              "meeting_id": "c3d4",
              "meeting_title": "1:1",
              "meeting_date": "2026-08-18T14:30:00Z",
              "participants": ["Carlos"]
            }
          ]
        }
        """))
        #expect(reunioes.count == 2)
        #expect(reunioes[0].id == "a1b2")
        #expect(reunioes[0].titulo == "Planejamento Q3")
        #expect(reunioes[0].data == iso.date(from: "2026-08-19T10:00:00Z"))
        #expect(reunioes[0].participantes.map(\.displayNome) == ["Ana", "Bia"])
        #expect(reunioes[0].participantes[0].email == "ana@granola.ai")
        #expect(reunioes[1].participantes.map(\.displayNome) == ["Carlos"])
        #expect(!reunioes[0].temTranscricao)
    }

    @Test("detalhe preenche notas e resumo de entre as chaves candidatas")
    func mapeiaDetalhe() throws {
        let reuniao = try mapeador.reuniao(id: "a1b2", da: json("""
        {
          "meetings": [
            {
              "meeting_id": "a1b2",
              "meeting_title": "Planejamento Q3",
              "meeting_date": "2026-08-19T10:00:00Z",
              "notes_markdown": "## Anotações\\n- decisão A",
              "summary_markdown": "Resumo gerado pelo Granola."
            }
          ]
        }
        """))
        #expect(reuniao.notas?.contains("decisão A") == true)
        #expect(reuniao.resumo == "Resumo gerado pelo Granola.")
    }

    @Test("detalhe com forma alternativa (objeto único, notas aninhadas) também funciona")
    func mapeiaDetalheAlternativo() throws {
        let reuniao = try mapeador.reuniao(id: "a1b2", da: json("""
        {
          "meeting": {
            "meeting_id": "a1b2",
            "meeting_title": "Planejamento Q3",
            "meeting_date": "2026-08-19",
            "notes": {"text": "Anotações em objeto"},
            "summary": "Resumo alternativo"
          }
        }
        """))
        #expect(reuniao.notas == "Anotações em objeto")
        #expect(reuniao.resumo == "Resumo alternativo")
        #expect(reuniao.data == iso.date(from: "2026-08-19T00:00:00Z"))
    }

    @Test("transcrição converte timestamps absolutos em segundos relativos à reunião")
    func mapeiaTranscricao() throws {
        let dataDaReuniao = iso.date(from: "2026-08-19T10:00:00Z")!
        let segmentos = try mapeador.transcricao(da: json("""
        {
          "transcript": [
            {
              "speaker": {"name": "Alice Smith"},
              "text": "Vamos fechar o escopo.",
              "start_time": "2026-08-19T10:00:05Z",
              "end_time": "2026-08-19T10:00:12Z"
            },
            {
              "speaker": {"attribution": "me"},
              "text": "Combinado.",
              "start_time": "2026-08-19T10:00:13Z",
              "end_time": "2026-08-19T10:00:15Z"
            },
            {
              "speaker": {"diarization_label": "Speaker A"},
              "text": "Sem horário."
            }
          ]
        }
        """), dataDaReuniao: dataDaReuniao)
        #expect(segmentos.count == 3)
        #expect(segmentos[0].falante == "Alice Smith")
        #expect(segmentos[0].texto == "Vamos fechar o escopo.")
        #expect(segmentos[0].inicio == 5)
        #expect(segmentos[0].fim == 12)
        #expect(segmentos[1].falante == "me")
        #expect(segmentos[2].falante == "Speaker A")
        #expect(segmentos[2].inicio == nil)
    }

    @Test("momento aceita segundos numéricos, ISO e devolve nil sem âncora")
    func momentoNumerico() {
        #expect(MapeadorGranola.momento(de: .numero(12.5), relativoA: nil) == 12.5)
        #expect(MapeadorGranola.momento(de: nil, relativoA: nil) == nil)
        #expect(MapeadorGranola.momento(de: .texto("2026-08-19T10:00:05Z"), relativoA: iso.date(from: "2026-08-19T10:00:00Z")) == 5)
    }

    @Test("reunião sem id lança erro claro")
    func listaSemIdFalha() {
        let resposta = json("""
        {"meetings": [{"meeting_title": "Sem id"}]}
        """)
        #expect(throws: ErroMCP.self) {
            _ = try mapeador.lista(de: resposta)
        }
    }
}