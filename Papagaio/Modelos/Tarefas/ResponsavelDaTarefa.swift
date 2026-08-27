import Foundation

struct ResponsavelDaTarefa: Identifiable, Hashable {
    var id: String {
        let emailLimpo = email.trimmingCharacters(in: .whitespacesAndNewlines)
        if !emailLimpo.isEmpty { return "email:\(emailLimpo.lowercased())" }

        let nomeLimpo = nome
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
        return "nome:\(nomeLimpo)"
    }
    let nome: String
    let email: String

    var rotulo: String {
        email.isEmpty ? nome : "\(nome) - \(email)"
    }

    /// Pessoas já registradas na ficha da própria conversa.
    ///
    /// Nome e e-mail são armazenados em linhas paralelas. Preservar as linhas
    /// vazias durante a associação é importante: remover um nome vazio antes
    /// de parear deslocaria todos os e-mails seguintes para a pessoa errada.
    static func disponiveis(em metadados: MetadadosVisuaisDoArquivo) -> [Self] {
        let grupos = [
            (metadados.entrevistadores, metadados.emailDosEntrevistadores),
            (metadados.entrevistado, metadados.emailDoEntrevistado),
        ]

        var resultado: [Self] = []
        var ids = Set<String>()

        for (nomes, emails) in grupos {
            let linhasDeNomes = nomes.components(separatedBy: .newlines)
            let linhasDeEmails = emails.components(separatedBy: .newlines)
            let quantidade = max(linhasDeNomes.count, linhasDeEmails.count)

            for indice in 0..<quantidade {
                let nome = linhasDeNomes.indices.contains(indice)
                    ? linhasDeNomes[indice].trimmingCharacters(in: .whitespacesAndNewlines)
                    : ""
                let email = linhasDeEmails.indices.contains(indice)
                    ? linhasDeEmails[indice].trimmingCharacters(in: .whitespacesAndNewlines)
                    : ""
                guard !nome.isEmpty || !email.isEmpty else { continue }

                let pessoa = Self(nome: nome.isEmpty ? email : nome, email: email)
                guard ids.insert(pessoa.id).inserted else { continue }
                resultado.append(pessoa)
            }
        }

        return resultado
    }
}
