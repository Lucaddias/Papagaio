import Foundation
import PapagaioCore

/// Uma pasta apagada, com tudo o que é preciso para trazê-la de volta.
///
/// Guarda os **ids das conversas** que estavam nela, e não as conversas: pasta
/// é um rótulo, e apagá-la nunca move nem apaga áudio. Restaurar é recolocar o
/// rótulo em quem o tinha.
struct PastaNaLixeira: Identifiable, Codable, Equatable {
    let id: UUID
    let nome: String
    let conversas: [UUID]
    let aparencia: AparenciaDasPastas.Estado
    let apagadaEm: Date

    init(
        id: UUID = UUID(),
        nome: String,
        conversas: [UUID],
        aparencia: AparenciaDasPastas.Estado,
        apagadaEm: Date = Date()
    ) {
        self.id = id
        self.nome = nome
        self.conversas = conversas
        self.aparencia = aparencia
        self.apagadaEm = apagadaEm
    }
}

/// A lixeira das pastas, no mesmo contrato das outras: listar, mandar para lá,
/// restaurar, apagar de vez, esvaziar.
enum LixeiraDePastas {
    private static let chave = "pastasNaLixeira"

    static func itens() -> [PastaNaLixeira] {
        guard let dados = UserDefaults.standard.data(forKey: chave),
              let itens = try? JSONDecoder().decode([PastaNaLixeira].self, from: dados)
        else { return [] }
        return itens.sorted { $0.apagadaEm > $1.apagadaEm }
    }

    static func guardar(_ item: PastaNaLixeira) {
        var atuais = itens()
        atuais.append(item)
        salvar(atuais)
    }

    /// Recria a pasta e repõe a aparência, sem tocar nas conversas.
    ///
    /// Quem devolve as conversas é a biblioteca, que é dona da lixeira delas —
    /// aqui só volta o rótulo. Ver `devolverRotulo`.
    @MainActor
    static func restaurar(_ item: PastaNaLixeira) {
        PreferenciasVisuaisDoArquivo.criarPasta(item.nome)
        AparenciaDasPastas.restaurar(item.aparencia, para: item.nome)
        remover(item)
    }

    /// Recoloca o rótulo da pasta numa conversa que acabou de sair da lixeira.
    ///
    /// Conversa que já foi para outra pasta nesse meio-tempo **fica onde
    /// está**: a escolha mais recente da pessoa vale mais do que o estado de
    /// antes da exclusão.
    @MainActor
    static func devolverRotulo(_ nome: String, para id: ArquivoID) {
        guard PreferenciasVisuaisDoArquivo.pasta(id) == nil else { return }
        PreferenciasVisuaisDoArquivo.definirPasta(nome, para: id)
    }

    /// A pasta a que uma conversa na lixeira pertencia, se foi apagada junto.
    static func pastaDe(_ id: ArquivoID) -> PastaNaLixeira? {
        itens().first { $0.conversas.contains(id.rawValue) }
    }

    static func remover(_ item: PastaNaLixeira) {
        salvar(itens().filter { $0.id != item.id })
    }

    @MainActor
    static func restaurarTudo() {
        for item in itens() { restaurar(item) }
    }

    /// Tira uma conversa da pasta apagada sem restaurar a pasta.
    ///
    /// Usado quando a pessoa restaura só um arquivo de dentro dela: a pasta
    /// segue na lixeira, mas deixa de reclamar aquele arquivo — senão
    /// restaurá-la depois tentaria trazer de volta algo que já voltou.
    static func desvincular(_ id: ArquivoID) {
        let atuais = itens().map { item -> PastaNaLixeira in
            guard item.conversas.contains(id.rawValue) else { return item }
            return PastaNaLixeira(
                id: item.id,
                nome: item.nome,
                conversas: item.conversas.filter { $0 != id.rawValue },
                aparencia: item.aparencia,
                apagadaEm: item.apagadaEm
            )
        }
        salvar(atuais)
    }

    static func esvaziar() {
        UserDefaults.standard.removeObject(forKey: chave)
    }

    private static func salvar(_ itens: [PastaNaLixeira]) {
        guard let dados = try? JSONEncoder().encode(itens) else { return }
        UserDefaults.standard.set(dados, forKey: chave)
    }
}
