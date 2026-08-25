import CloudKit
import Foundation
import PapagaioCore

/// Espelha os dados textuais da conversa no workspace da equipe.
///
/// O áudio e anexos não entram aqui: eles usam `CKAsset` numa fase separada,
/// para que nenhum membro receba uma conversa cuja mídia ainda não baixou.
actor SincronizadorDaBibliotecaCloudKit {
    private enum Campo {
        static let dados = "dados"
    }

    private static let tipoDeRegistro = "Conversa"
    private let container: CKContainer

    init(container: CKContainer = CKContainer(identifier: ServicoDeEquipesCloudKit.identificadorDoContainer)) {
        self.container = container
    }

    func enviar(_ arquivo: Arquivo, para equipe: EquipeDisponivel) async throws {
        let zona = try zonaDaEquipe(equipe)
        let banco = try bancoDaEquipe(equipe)
        let id = CKRecord.ID(recordName: arquivo.id.rawValue.uuidString, zoneID: zona)
        let registro = try await registroExistente(ouNovo: id, no: banco)
        registro[Campo.dados] = try JSONEncoder().encode(arquivo) as NSData
        _ = try await banco.save(registro)
    }

    func baixar(da equipe: EquipeDisponivel) async throws -> [Arquivo] {
        let zona = try zonaDaEquipe(equipe)
        let banco = try bancoDaEquipe(equipe)
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
        let espacoEsperado = try espacoDaEquipe(equipe)

        return try resposta.matchResults.compactMap { _, resultado in
            let registro = try resultado.get()
            guard let dados = registro[Campo.dados] as? Data else { return nil }
            let arquivo = try JSONDecoder().decode(Arquivo.self, from: dados)
            return arquivo.espaco == espacoEsperado ? arquivo : nil
        }
    }

    func remover(_ arquivo: Arquivo, da equipe: EquipeDisponivel) async throws {
        let zona = try zonaDaEquipe(equipe)
        let banco = try bancoDaEquipe(equipe)
        let id = CKRecord.ID(recordName: arquivo.id.rawValue.uuidString, zoneID: zona)
        _ = try await banco.modifyRecords(
            saving: [],
            deleting: [id],
            savePolicy: .ifServerRecordUnchanged,
            atomically: true
        )
    }

    private func registroExistente(ouNovo id: CKRecord.ID, no banco: CKDatabase) async throws -> CKRecord {
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

    private func espacoDaEquipe(_ equipe: EquipeDisponivel) throws -> EspacoID {
        guard let texto = equipe.espacoID, let id = UUID(uuidString: texto) else {
            throw ErroDeEquipeCloudKit.equipeAindaLocal
        }
        return EspacoID(rawValue: id)
    }
}
