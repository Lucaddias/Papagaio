@preconcurrency import CloudKit
import Foundation

/// Store de um espaço de equipe. Diferente do store individual, usa CloudKit
/// puro numa custom zone, que é a única forma de usar `CKShare`.
public actor CloudKitRepository: ArquivoRepository {
    public static let containerIdentifier = "iCloud.com.papagaio.Papagaio"
    private static let tipoArquivo = "Arquivo"

    private let armazenamento: Armazenamento
    private let database: CKDatabase
    private let zoneID: CKRecordZone.ID
    private let delegate: DelegadoDeSync
    private let syncEngine: CKSyncEngine
    private var zonaCriada = false

    public init(
        espaco: EspacoID,
        armazenamento: Armazenamento,
        container: CKContainer = CKContainer(identifier: CloudKitRepository.containerIdentifier)
    ) {
        self.armazenamento = armazenamento
        database = container.privateCloudDatabase
        zoneID = CKRecordZone.ID(zoneName: "espaco-\(espaco.rawValue.uuidString)")
        let estado = armazenamento.resolver(
            relativo: "CloudKit/\(espaco.rawValue.uuidString)-sync-state.json"
        )
        let serializacao = Self.lerSerializacao(do: estado)
        let delegate = DelegadoDeSync(urlDoEstado: estado)
        self.delegate = delegate
        syncEngine = CKSyncEngine(.init(
            database: database,
            stateSerialization: serializacao,
            delegate: delegate
        ))
    }

    /// O app só deve oferecer equipe se a conta iCloud estiver disponível.
    public static func contaDisponivel(
        no container: CKContainer = CKContainer(identifier: CloudKitRepository.containerIdentifier)
    ) async -> Bool {
        (try? await container.accountStatus()) == .available
    }

    /// Identidade de sync — deliberadamente não é o identificador do Sign in
    /// with Apple do Passo 12.
    public static func identificadorDaConta(
        no container: CKContainer = CKContainer(identifier: CloudKitRepository.containerIdentifier)
    ) async throws -> CKRecord.ID {
        guard try await container.accountStatus() == .available else {
            throw ErroCloudKit.semContaICloud
        }
        return try await container.userRecordID()
    }

    public func salvar(_ arquivo: Arquivo) async throws {
        try await garantirZona()
        let record = try record(para: arquivo)
        await delegate.enfileirar(record)
        syncEngine.state.add(pendingRecordZoneChanges: [.saveRecord(record.recordID)])
        try await syncEngine.sendChanges()
    }

    public func listar(espaco: EspacoID) async throws -> [Arquivo] {
        try await garantirZona()
        let query = CKQuery(
            recordType: Self.tipoArquivo,
            predicate: NSPredicate(format: "espacoID == %@", espaco.rawValue.uuidString)
        )
        let records = try await registros(matching: query)
        return try records.map { try decodificar($0) }.sorted { $0.criadoEm > $1.criadoEm }
    }

    public func buscar(termo: String) async throws -> [Arquivo] {
        let limpo = termo.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !limpo.isEmpty else { return [] }
        try await garantirZona()
        let query = CKQuery(recordType: Self.tipoArquivo, predicate: NSPredicate(value: true))
        let todos = try await registros(matching: query).map { try decodificar($0) }
        return todos
            .filter { $0.titulo.localizedStandardContains(limpo) || $0.trechos.contains { $0.texto.localizedStandardContains(limpo) } }
            .sorted { $0.criadoEm > $1.criadoEm }
    }

    public func apagar(_ id: ArquivoID) async throws {
        try await garantirZona()
        let recordID = CKRecord.ID(recordName: id.rawValue.uuidString, zoneID: zoneID)
        syncEngine.state.add(pendingRecordZoneChanges: [.deleteRecord(recordID)])
        try await syncEngine.sendChanges()
    }

    /// Cria um convite para compartilhar a zone inteira com a equipe.
    public func criarConvite() async throws -> URL {
        try await garantirZona()
        let share = CKShare(recordZoneID: zoneID)
        share[CKShare.SystemFieldKey.title] = "Espaço Papagaio" as NSString
        share.publicPermission = .none
        let salvo = try await database.save(share)
        guard let url = (salvo as? CKShare)?.url else { throw ErroCloudKit.conviteIndisponivel }
        return url
    }

    private func garantirZona() async throws {
        guard !zonaCriada else { return }
        do {
            _ = try await database.recordZone(for: zoneID)
        } catch let erro as CKError where erro.code == .zoneNotFound {
            _ = try await database.save(CKRecordZone(zoneID: zoneID))
        }
        zonaCriada = true
    }

    private func registros(matching query: CKQuery) async throws -> [CKRecord] {
        let resultado = try await database.records(
            matching: query,
            inZoneWith: zoneID,
            desiredKeys: nil,
            resultsLimit: CKQueryOperation.maximumResults
        )
        return try resultado.matchResults.map { try $0.1.get() }
    }

    private static func lerSerializacao(
        do url: URL
    ) -> CKSyncEngine.State.Serialization? {
        guard let dados = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(CKSyncEngine.State.Serialization.self, from: dados)
    }

    private func record(para arquivo: Arquivo) throws -> CKRecord {
        let id = CKRecord.ID(recordName: arquivo.id.rawValue.uuidString, zoneID: zoneID)
        let record = CKRecord(recordType: Self.tipoArquivo, recordID: id)
        let envelope = Envelope(arquivo: arquivo)
        record["espacoID"] = arquivo.espaco.rawValue.uuidString as NSString
        record["titulo"] = arquivo.titulo as NSString
        record["payload"] = try JSONEncoder().encode(envelope) as NSData

        let pasta = armazenamento.resolver(relativo: arquivo.pastaRelativa)
        try FileManager.default.createDirectory(at: pasta, withIntermediateDirectories: true)
        let audio = pasta.appendingPathComponent(Armazenamento.Nome.mixagem)
        if FileManager.default.fileExists(atPath: audio.path) {
            record["audio"] = CKAsset(fileURL: audio)
        }
        let markdown = pasta.appendingPathComponent("resumo.md")
        try ExportacaoMarkdown.gerar(arquivo: arquivo).write(to: markdown, atomically: true, encoding: .utf8)
        record["markdown"] = CKAsset(fileURL: markdown)
        return record
    }

    private func decodificar(_ record: CKRecord) throws -> Arquivo {
        guard let dados = record["payload"] as? Data else { throw ErroCloudKit.registroInvalido }
        let envelope = try JSONDecoder().decode(Envelope.self, from: dados)
        let arquivo = envelope.arquivo
        let pasta = armazenamento.resolver(relativo: arquivo.pastaRelativa)
        try FileManager.default.createDirectory(at: pasta, withIntermediateDirectories: true)
        if let origem = (record["audio"] as? CKAsset)?.fileURL {
            let destino = pasta.appendingPathComponent(Armazenamento.Nome.mixagem)
            if !FileManager.default.fileExists(atPath: destino.path) {
                try FileManager.default.copyItem(at: origem, to: destino)
            }
        }
        return arquivo
    }

    private struct Envelope: Codable, Sendable {
        let id: UUID
        let titulo: String
        let criadoEm: Date
        let duracao: TimeInterval
        let pastaRelativa: String
        let espaco: UUID
        let trechos: [Trecho]
        let resumo: Resumo?
        let engineTranscricao: String?
        let engineResumo: String?

        init(arquivo: Arquivo) {
            id = arquivo.id.rawValue; titulo = arquivo.titulo; criadoEm = arquivo.criadoEm
            duracao = arquivo.duracao; pastaRelativa = arquivo.pastaRelativa; espaco = arquivo.espaco.rawValue
            trechos = arquivo.trechos; resumo = arquivo.resumo
            engineTranscricao = arquivo.engineTranscricao; engineResumo = arquivo.engineResumo
        }

        var arquivo: Arquivo {
            Arquivo(id: ArquivoID(rawValue: id), titulo: titulo, criadoEm: criadoEm, duracao: duracao,
                    pastaRelativa: pastaRelativa, espaco: EspacoID(rawValue: espaco), trechos: trechos,
                    resumo: resumo, engineTranscricao: engineTranscricao, engineResumo: engineResumo)
        }
    }
}

public enum ErroCloudKit: LocalizedError {
    case semContaICloud, conviteIndisponivel, registroInvalido
    public var errorDescription: String? {
        switch self {
        case .semContaICloud: "Entre no iCloud do sistema para usar um espaço de equipe."
        case .conviteIndisponivel: "Não foi possível criar o convite do espaço."
        case .registroInvalido: "Um registro recebido do espaço está inválido."
        }
    }
}

private actor DelegadoDeSync: CKSyncEngineDelegate {
    private var pendentes: [CKRecord.ID: CKRecord] = [:]
    private let urlDoEstado: URL

    init(urlDoEstado: URL) {
        self.urlDoEstado = urlDoEstado
    }

    func enfileirar(_ record: CKRecord) { pendentes[record.recordID] = record }

    func handleEvent(_ event: CKSyncEngine.Event, syncEngine: CKSyncEngine) async {
        if case let .stateUpdate(atualizacao) = event {
            salvar(atualizacao.stateSerialization)
        } else if case let .sentRecordZoneChanges(resultado) = event {
            for record in resultado.savedRecords { pendentes[record.recordID] = nil }
            for id in resultado.deletedRecordIDs { pendentes[id] = nil }
        }
    }

    func nextRecordZoneChangeBatch(
        _ context: CKSyncEngine.SendChangesContext,
        syncEngine: CKSyncEngine
    ) async -> CKSyncEngine.RecordZoneChangeBatch? {
        guard !pendentes.isEmpty else { return nil }
        return CKSyncEngine.RecordZoneChangeBatch(recordsToSave: Array(pendentes.values), atomicByZone: true)
    }

    private func salvar(_ serializacao: CKSyncEngine.State.Serialization) {
        guard let dados = try? JSONEncoder().encode(serializacao) else { return }
        try? FileManager.default.createDirectory(
            at: urlDoEstado.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try? dados.write(to: urlDoEstado, options: .atomic)
    }
}
