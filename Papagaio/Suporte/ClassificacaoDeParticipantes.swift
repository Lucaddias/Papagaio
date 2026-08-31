import Foundation
import PapagaioCore

/// Classifica participantes do Calendar em Equipe vs Externos com base nos
/// emails da equipe ativa (só equipe ativa, conforme decisão).
///
/// Mantém a ordem original do evento. O próprio email (self) vai para Equipe.
enum ClassificacaoDeParticipantes {
    struct Resultado {
        var equipeNomes: String      // "\n" separado
        var equipeEmails: String
        var externosNomes: String
        var externosEmails: String
    }

    /// Emails da equipe ativa normalizados (lowercased).
    static func emailsDaEquipeAtiva(_ equipe: EquipeDisponivel?) -> Set<String> {
        guard let equipe else { return [] }
        let membros = MembrosDasEquipes.carregar(equipeID: equipe.id)
        return Set(membros.compactMap { $0.email.emailNormalizado })
    }

    /// Classifica; usa cache simples para complementar nome<>email.
    static func classificar(
        _ participantes: [ParticipanteDaReuniao],
        equipe: EquipeDisponivel?
    ) -> Resultado {
        let equipeEmails = emailsDaEquipeAtiva(equipe)
        var eqNomes: [String] = []
        var eqEmails: [String] = []
        var extNomes: [String] = []
        var extEmails: [String] = []

        // Cache leve email->nome para complementar ausências futuras
        var cache = CacheDeNomes.carregar()

        for p in participantes {
            let emailNorm = p.email?.emailNormalizado
            let nome = p.nome?.trimmingCharacters(in: .whitespacesAndNewlines)
            let email = p.email?.trimmingCharacters(in: .whitespacesAndNewlines)

            // Atualiza cache quando tem ambos
            if let e = emailNorm, let n = nome, !n.isEmpty {
                cache[e] = n
            }
            // Complementa nome faltante via cache ou prefixo do email
            var nomeEfetivo = nome
            if (nomeEfetivo == nil || nomeEfetivo?.isEmpty == true), let e = emailNorm {
                if let cached = cache[e] {
                    nomeEfetivo = cached
                } else if let eRaw = email, eRaw.contains("@") {
                    let prefix = eRaw.split(separator: "@").first.map(String.init) ?? ""
                    // Capitaliza "joao.silva" -> "Joao Silva"
                    let derivado = prefix.replacingOccurrences(of: ".", with: " ").replacingOccurrences(of: "_", with: " ").replacingOccurrences(of: "-", with: " ")
                    nomeEfetivo = derivado.split(separator: " ").map { $0.capitalized }.joined(separator: " ")
                    if nomeEfetivo?.isEmpty == true { nomeEfetivo = nil }
                }
            }
            // Complementa email faltante via cache inverso (nome->email) se houver
            // (por enquanto só usa cache email->nome; o inverso exigiria mapa nome->email
            //  que pode colidir — não fazemos).

            let isEquipe: Bool
            if let eNorm = emailNorm {
                isEquipe = equipeEmails.contains(eNorm) || p.isSelf
            } else {
                isEquipe = false
            }

            // Nome e email alinhados por linha — linha vazia quando ausente mantém índice
            let nomeLinha = nomeEfetivo ?? nome ?? ""
            let emailLinha = email ?? ""

            if isEquipe {
                eqNomes.append(nomeLinha)
                eqEmails.append(emailLinha)
            } else {
                extNomes.append(nomeLinha)
                extEmails.append(emailLinha)
            }
        }

        if !cache.isEmpty {
            CacheDeNomes.salvar(cache)
        }

        return Resultado(
            equipeNomes: eqNomes.joined(separator: "\n"),
            equipeEmails: eqEmails.joined(separator: "\n"),
            externosNomes: extNomes.joined(separator: "\n"),
            externosEmails: extEmails.joined(separator: "\n")
        )
    }
}

// MARK: - Cache simples email -> nome

private enum CacheDeNomes {
    static let chave = "cacheNomePorEmail"

    static func carregar() -> [String: String] {
        guard let dados = UserDefaults.standard.data(forKey: chave),
              let mapa = try? JSONDecoder().decode([String: String].self, from: dados)
        else { return [:] }
        return mapa
    }

    static func salvar(_ mapa: [String: String]) {
        guard let dados = try? JSONEncoder().encode(mapa) else { return }
        UserDefaults.standard.set(dados, forKey: chave)
    }
}

private extension String {
    var emailNormalizado: String {
        lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
