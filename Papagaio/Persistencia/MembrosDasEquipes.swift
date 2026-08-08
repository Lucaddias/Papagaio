import Foundation

enum MembrosDasEquipes {
    private static func chave(_ equipeID: String) -> String {
        "membrosDaEquipe.\(equipeID)"
    }

    static func carregar(equipeID: String) -> [MembroDaEquipe] {
        if let dados = UserDefaults.standard.data(forKey: chave(equipeID)),
           let membros = try? JSONDecoder().decode([MembroDaEquipe].self, from: dados) {
            return membros
        }

        let membros = membrosPadrao(equipeID: equipeID)
        salvar(membros, equipeID: equipeID)
        return membros
    }

    static func salvar(_ membros: [MembroDaEquipe], equipeID: String) {
        guard let dados = try? JSONEncoder().encode(membros) else { return }
        UserDefaults.standard.set(dados, forKey: chave(equipeID))
    }

    private static func membrosPadrao(equipeID: String) -> [MembroDaEquipe] {
        switch equipeID {
        case "creative-flow":
            [
                MembroDaEquipe(nome: "Ricardo Silva", email: "ricardo.silva@scribeflow.io", cargo: "Administrador", status: .ativo, atual: true),
                MembroDaEquipe(nome: "Beatriz Martins", email: "beatriz.m@scribeflow.io", cargo: "Transcritor", status: .ativo),
                MembroDaEquipe(nome: "Lucas Oliveira", email: "lucas.oliveira@design.com", cargo: "Designer", status: .ocupado),
                MembroDaEquipe(nome: "Fernanda Costa", email: "f.costa@scribeflow.io", cargo: "Transcritor", status: .offline),
                MembroDaEquipe(nome: "João Silva", email: "joao.silva@scribeflow.io", cargo: "Pesquisador", status: .ocupado)
            ]
        case "scribeflow":
            [
                MembroDaEquipe(nome: "Ricardo Silva", email: "ricardo.silva@scribeflow.io", cargo: "Administrador", status: .ativo, atual: true),
                MembroDaEquipe(nome: "Camila Rocha", email: "camila@scribeflow.io", cargo: "Revisora", status: .offline),
                MembroDaEquipe(nome: "Pedro Lima", email: "pedro@scribeflow.io", cargo: "Transcritor", status: .ativo)
            ]
        case "design-lab":
            [
                MembroDaEquipe(nome: "Ricardo Silva", email: "ricardo.silva@design.com", cargo: "Administrador", status: .ativo, atual: true),
                MembroDaEquipe(nome: "Ana Costa", email: "ana@design.com", cargo: "Designer", status: .ativo)
            ]
        default:
            [
                MembroDaEquipe(nome: "Ricardo Silva", email: "ricardo.silva@scribeflow.io", cargo: "Administrador", status: .ativo, atual: true)
            ]
        }
    }
}
