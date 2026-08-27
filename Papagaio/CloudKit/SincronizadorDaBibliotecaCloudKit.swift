import CloudKit
import Foundation
import PapagaioCore

/// Cursor opaco: produção guarda `CKQueryOperation.Cursor`; testes usam um
/// marcador simples sem importar detalhes do transporte.
final class CursorDeConversasCloudKit: @unchecked Sendable {
    fileprivate let valor: Any

    init(_ valor: Any) {
        self.valor = valor
    }
}

struct PaginaDeConversasCloudKit: Sendable {
    let registros: [Data]
    let proxima: CursorDeConversasCloudKit?
}

/// Limite testável entre regras de sincronização e as APIs concretas do
/// CloudKit. Nenhum double precisa construir `CKContainer` ou acessar iCloud.
protocol TransporteDeConversasCloudKit: Sendable {
    func salvar(_ dados: Data, id: String, equipe: EquipeDisponivel) async throws
    func pagina(
        da equipe: EquipeDisponivel,
        continuando cursor: CursorDeConversasCloudKit?
    ) async throws -> PaginaDeConversasCloudKit
    func remover(id: String, equipe: EquipeDisponivel) async throws
}

/// Implementação concreta do transporte. Todo acesso a `CKDatabase` fica
/// isolado neste ator; o sincronizador acima dele trabalha apenas com `Data`.
actor TransporteDeConversasCloudKitReal: TransporteDeConversasCloudKit {
    private enum Campo {
        static let dados = "dados"
    }

    private static let tipoDeRegistro = "Conversa"
    private let container: CKContainer

    init(container: CKContainer) {
        self.container = container
    }

    func salvar(_ dados: Data, id: String, equipe: EquipeDisponivel) async throws {
        let zona = try zonaDaEquipe(equipe)
        let banco = try bancoDaEquipe(equipe)
        let recordID = CKRecord.ID(recordName: id, zoneID: zona)
        let registro = try await registroExistente(ouNovo: recordID, no: banco)
        registro[Campo.dados] = dados as NSData
        _ = try await banco.save(registro)
    }

    func pagina(
        da equipe: EquipeDisponivel,
        continuando cursor: CursorDeConversasCloudKit?
    ) async throws -> PaginaDeConversasCloudKit {
        let zona = try zonaDaEquipe(equipe)
        let banco = try bancoDaEquipe(equipe)

        if let cursor {
            guard let cursorCloudKit = cursor.valor as? CKQueryOperation.Cursor else {
                throw ErroDeEquipeCloudKit.cursorInvalido
            }
            let resposta = try await banco.records(
                continuingMatchFrom: cursorCloudKit,
                desiredKeys: [Campo.dados],
                resultsLimit: 200
            )
            return try Self.pagina(
                resultados: resposta.matchResults,
                proxima: resposta.queryCursor
            )
        }

        let consulta = CKQuery(
            recordType: Self.tipoDeRegistro,
            predicate: NSPredicate(value: true)
        )
        let resposta = try await banco.records(
            matching: consulta,
            inZoneWith: zona,
            desiredKeys: [Campo.dados],
            resultsLimit: 200
        )
        return try Self.pagina(
            resultados: resposta.matchResults,
            proxima: resposta.queryCursor
        )
    }

    func remover(id: String, equipe: EquipeDisponivel) async throws {
        let zona = try zonaDaEquipe(equipe)
        let banco = try bancoDaEquipe(equipe)
        let recordID = CKRecord.ID(recordName: id, zoneID: zona)
        _ = try await banco.modifyRecords(
            saving: [],
            deleting: [recordID],
            savePolicy: .ifServerRecordUnchanged,
            atomically: true
        )
    }

    private static func pagina(
        resultados: [(CKRecord.ID, Result<CKRecord, any Error>)],
        proxima: CKQueryOperation.Cursor?
    ) throws -> PaginaDeConversasCloudKit {
        let dados = try resultados.compactMap { _, resultado -> Data? in
            let registro = try resultado.get()
            return registro[Campo.dados] as? Data
        }
        return PaginaDeConversasCloudKit(
            registros: dados,
            proxima: proxima.map(CursorDeConversasCloudKit.init)
        )
    }

    private func registroExistente(
        ouNovo id: CKRecord.ID,
        no banco: CKDatabase
    ) async throws -> CKRecord {
        do {
            return try await banco.record(for: id)
        } catch let erro as CKError where erro.code == .unknownItem {
            return CKRecord(recordType: Self.tipoDeRegistro, recordID: id)
        }
    }

    private func bancoDaEquipe(_ equipe: EquipeDisponivel) throws -> CKDatabase {
        guard let banco = equipe.bancoCloudKit.flatMap(BancoCloudKitDaEquipe.init(rawValue:)) else {
            throw ErroDeEquipeCloudKit.equipeAindaLocal
        }
        return switch banco {
        case .privado: container.privateCloudDatabase
        case .compartilhado: container.sharedCloudDatabase
        }
    }

    private func zonaDaEquipe(_ equipe: EquipeDisponivel) throws -> CKRecordZone.ID {
        guard let nome = equipe.zonaCloudKit else {
            throw ErroDeEquipeCloudKit.equipeAindaLocal
        }
        return CKRecordZone.ID(zoneName: nome)
    }
}

/// Espelha os dados textuais da conversa no workspace da equipe.
///
/// O áudio e anexos não entram aqui. O payload compartilhado leva metadados,
/// transcrição, notas e resumo; a mídia permanece local até existir uma
/// política explícita de `CKAsset`.
actor SincronizadorDaBibliotecaCloudKit {
    private let transporte: any TransporteDeConversasCloudKit

    init(
        container: CKContainer = CKContainer(
            identifier: ServicoDeEquipesCloudKit.identificadorDoContainer
        )
    ) {
        self.transporte = TransporteDeConversasCloudKitReal(container: container)
    }

    init(transporte: any TransporteDeConversasCloudKit) {
        self.transporte = transporte
    }

    func enviar(_ arquivo: Arquivo, para equipe: EquipeDisponivel) async throws {
        let dados = try JSONEncoder().encode(arquivo)
        try await transporte.salvar(
            dados,
            id: arquivo.id.rawValue.uuidString,
            equipe: equipe
        )
    }

    func baixar(da equipe: EquipeDisponivel) async throws -> [Arquivo] {
        let espacoEsperado = try espacoDaEquipe(equipe)
        var cursor: CursorDeConversasCloudKit?
        var arquivos: [Arquivo] = []

        repeat {
            let pagina = try await transporte.pagina(da: equipe, continuando: cursor)
            for dados in pagina.registros {
                let arquivo = try JSONDecoder().decode(Arquivo.self, from: dados)
                guard arquivo.espaco == espacoEsperado else { continue }
                arquivos.append(arquivo)
            }
            cursor = pagina.proxima
        } while cursor != nil

        return arquivos
    }

    func remover(_ arquivo: Arquivo, da equipe: EquipeDisponivel) async throws {
        try await transporte.remover(
            id: arquivo.id.rawValue.uuidString,
            equipe: equipe
        )
    }

    private func espacoDaEquipe(_ equipe: EquipeDisponivel) throws -> EspacoID {
        guard let texto = equipe.espacoID, let id = UUID(uuidString: texto) else {
            throw ErroDeEquipeCloudKit.equipeAindaLocal
        }
        return EspacoID(rawValue: id)
    }
}
