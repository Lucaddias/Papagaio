import Foundation

enum VisibilidadeDosArquivosDaEquipe: String, CaseIterable, Codable, Identifiable {
    case todosOsMembros = "Todos os membros"
    case apenasAdministrador = "Somente administradores"

    var id: Self { self }
}

enum RecebimentoDeArquivosDaEquipe: String, CaseIterable, Codable, Identifiable {
    case automatico = "Entrar automaticamente"
    case aguardarRevisao = "Aguardar revisão"

    var id: Self { self }
}

struct ConfiguracoesDaEquipe: Codable, Hashable {
    var visibilidadeDosArquivos: VisibilidadeDosArquivosDaEquipe = .todosOsMembros
    var recebimentoDeArquivos: RecebimentoDeArquivosDaEquipe = .automatico
}

/// Uma equipe do usuário.
///
/// Não existe equipe padrão: um app recém-instalado não tem equipe nenhuma até
/// que a pessoa crie a primeira. Por isso todo consumidor trata `EquipeDisponivel?`
/// em vez de assumir que sempre há uma ativa.
struct EquipeDisponivel: Identifiable, Hashable, Codable {
    let id: String
    let nome: String
    let papel: String
    var quantidadeDeMembros: Int

    /// Referência do workspace compartilhado. Equipes criadas antes do
    /// CloudKit continuam locais até serem publicadas explicitamente.
    var espacoID: String?
    var zonaCloudKit: String?
    var compartilhamentoCloudKit: String?
    var bancoCloudKit: String?
    /// Código curto compartilhado para entrar na equipe. Não é uma senha: ele
    /// apenas resolve o convite CloudKit público desta equipe.
    var codigoDeEntrada: String?
    var configuracoes: ConfiguracoesDaEquipe

    init(
        id: String,
        nome: String,
        papel: String,
        quantidadeDeMembros: Int,
        espacoID: String? = nil,
        zonaCloudKit: String? = nil,
        compartilhamentoCloudKit: String? = nil,
        bancoCloudKit: String? = nil,
        codigoDeEntrada: String? = nil,
        configuracoes: ConfiguracoesDaEquipe = .init()
    ) {
        self.id = id
        self.nome = nome
        self.papel = papel
        self.quantidadeDeMembros = quantidadeDeMembros
        self.espacoID = espacoID
        self.zonaCloudKit = zonaCloudKit
        self.compartilhamentoCloudKit = compartilhamentoCloudKit
        self.bancoCloudKit = bancoCloudKit
        self.codigoDeEntrada = codigoDeEntrada
        self.configuracoes = configuracoes
    }

    static func novoCodigoDeEntrada() -> String {
        let alfabeto = Array("ABCDEFGHJKLMNPQRSTUVWXYZ23456789")
        return (0..<6).map { _ in String(alfabeto.randomElement()!) }.joined()
    }
}
