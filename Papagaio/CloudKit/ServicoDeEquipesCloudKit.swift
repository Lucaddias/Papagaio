import CloudKit
import Foundation

/// Workspaces colaborativos no container do Papagaio.
///
/// Cada equipe vive numa zona privada própria e a zona inteira recebe um
/// `CKShare`. Assim, os próximos tipos de registro (conversa, tarefa e mídia)
/// entram no mesmo escopo sem que seja necessário compartilhar item a item.
actor ServicoDeEquipesCloudKit {
    static let identificadorDoContainer = "iCloud.com.papagaio.Papagaio"

    private enum Campo {
        static let id = "id"
        static let nome = "nome"
        static let espacoID = "espacoID"
        static let codigoDeEntrada = "codigoDeEntrada"
        static let configuracoes = "configuracoes"
        static let urlDoCompartilhamento = "urlDoCompartilhamento"
    }

    private enum TipoDeRegistro {
        static let equipe = "Equipe"
        static let codigoDeEquipe = "CodigoDeEquipe"
    }

    private let container: CKContainer

    init(container: CKContainer = CKContainer(identifier: "iCloud.com.papagaio.Papagaio")) {
        self.container = container
    }

    /// Cria o workspace e o compartilhamento da zona de uma equipe nova.
    ///
    /// O link não concede acesso sozinho: a fase de UI adicionará os e-mails
    /// dos membros como participantes privados antes de distribuí-lo.
    func criarWorkspace(para equipe: EquipeDisponivel) async throws -> EquipeDisponivel {
        try await garantirContaICloudDisponivel()

        let zonaID = CKRecordZone.ID(
            zoneName: Self.nomeDaZona(para: equipe.id)
        )
        let banco = container.privateCloudDatabase
        _ = try await banco.save(CKRecordZone(zoneID: zonaID))

        let espacoID = UUID(uuidString: equipe.espacoID ?? "") ?? UUID()
        let registro = registroDaEquipe(equipe, espacoID: espacoID, na: zonaID)
        let compartilhamento = CKShare(recordZoneID: zonaID)
        compartilhamento[CKShare.SystemFieldKey.title] = equipe.nome as NSString
        compartilhamento.publicPermission = .readWrite

        _ = try await banco.modifyRecords(
            saving: [registro, compartilhamento],
            deleting: [],
            savePolicy: .ifServerRecordUnchanged,
            atomically: true
        )

        guard let url = compartilhamento.url else {
            throw ErroDeEquipeCloudKit.conviteIndisponivel
        }
        try await publicarCodigo(equipe.codigoDeEntrada, para: url)

        return EquipeDisponivel(
            id: equipe.id,
            nome: equipe.nome,
            papel: equipe.papel,
            quantidadeDeMembros: equipe.quantidadeDeMembros,
            espacoID: espacoID.uuidString,
            zonaCloudKit: zonaID.zoneName,
            compartilhamentoCloudKit: compartilhamento.recordID.recordName,
            bancoCloudKit: BancoCloudKitDaEquipe.privado.rawValue,
            codigoDeEntrada: equipe.codigoDeEntrada,
            configuracoes: equipe.configuracoes
        )
    }

    /// Resolve o código informado e aceita a zona compartilhada da equipe.
    func entrarNaEquipe(com codigo: String) async throws -> EquipeDisponivel {
        try await garantirContaICloudDisponivel()
        let codigoNormalizado = Self.normalizar(codigo)
        let consulta = CKQuery(
            recordType: TipoDeRegistro.codigoDeEquipe,
            predicate: NSPredicate(format: "%K == %@", Campo.codigoDeEntrada, codigoNormalizado)
        )
        let resultado = try await container.publicCloudDatabase.records(matching: consulta)
        guard let registro = try resultado.matchResults.first?.1.get(),
              let textoDaURL = registro[Campo.urlDoCompartilhamento] as? String,
              let url = URL(string: textoDaURL) else {
            throw ErroDeEquipeCloudKit.codigoInvalido
        }
        let metadados = try await container.shareMetadata(for: url)
        return try await aceitar(metadados)
    }

    /// Somente a conta proprietária altera as preferências compartilhadas.
    func atualizarConfiguracoes(_ configuracoes: ConfiguracoesDaEquipe, da equipe: EquipeDisponivel) async throws {
        try await garantirContaICloudDisponivel()
        guard equipe.bancoCloudKit == BancoCloudKitDaEquipe.privado.rawValue else {
            throw ErroDeEquipeCloudKit.apenasAdministrador
        }
        let zona = try referenciaDaZona(de: equipe)
        let id = CKRecord.ID(recordName: "equipe", zoneID: zona)
        let registro = try await container.privateCloudDatabase.record(for: id)
        registro[Campo.configuracoes] = try JSONEncoder().encode(configuracoes) as NSData
        _ = try await container.privateCloudDatabase.save(registro)
    }

    /// Inclui um membro identificado pelo e-mail do Apple Account com acesso
    /// de leitura e escrita ao workspace completo da equipe.
    func adicionarMembro(email: String, a equipe: EquipeDisponivel) async throws {
        try await garantirContaICloudDisponivel()
        let referencia = try referenciaDaZona(de: equipe)
        let idDoCompartilhamento = try idDoCompartilhamento(de: equipe, na: referencia)
        let banco = container.privateCloudDatabase
        let compartilhamento = try await banco.record(for: idDoCompartilhamento) as! CKShare
        let participante = try await container.shareParticipant(forEmailAddress: email)

        participante.permission = .readWrite
        compartilhamento.addParticipant(participante)
        _ = try await banco.save(compartilhamento)
    }

    /// Aceita um convite entregue pelo sistema e devolve a equipe para a lista
    /// local do participante. Os registros passam a aparecer no banco
    /// compartilhado dessa conta.
    func aceitar(_ metadados: CKShare.Metadata) async throws -> EquipeDisponivel {
        try await garantirContaICloudDisponivel()
        let compartilhamento = try await container.accept(metadados)
        let zonaID = compartilhamento.recordID.zoneID
        let registroID = CKRecord.ID(recordName: "equipe", zoneID: zonaID)
        let registro = try await container.sharedCloudDatabase.record(for: registroID)

        guard
            let id = registro[Campo.id] as? String,
            let nome = registro[Campo.nome] as? String,
            let espacoID = registro[Campo.espacoID] as? String,
            UUID(uuidString: espacoID) != nil
        else {
            throw ErroDeEquipeCloudKit.registroDaEquipeInvalido
        }

        return EquipeDisponivel(
            id: id,
            nome: nome,
            papel: "Membro",
            quantidadeDeMembros: 0,
            espacoID: espacoID,
            zonaCloudKit: zonaID.zoneName,
            compartilhamentoCloudKit: compartilhamento.recordID.recordName,
            bancoCloudKit: BancoCloudKitDaEquipe.compartilhado.rawValue,
            codigoDeEntrada: registro[Campo.codigoDeEntrada] as? String,
            configuracoes: configuracoes(no: registro)
        )
    }

    nonisolated static func nomeDaZona(para equipeID: String) -> String {
        "equipe.\(equipeID)"
    }

    nonisolated static func normalizar(_ codigo: String) -> String {
        codigo.uppercased().filter { $0.isLetter || $0.isNumber }
    }

    private func garantirContaICloudDisponivel() async throws {
        guard try await container.accountStatus() == .available else {
            throw ErroDeEquipeCloudKit.contaICloudIndisponivel
        }
    }

    private func registroDaEquipe(
        _ equipe: EquipeDisponivel,
        espacoID: UUID,
        na zonaID: CKRecordZone.ID
    ) -> CKRecord {
        let registro = CKRecord(
            recordType: TipoDeRegistro.equipe,
            recordID: CKRecord.ID(recordName: "equipe", zoneID: zonaID)
        )
        registro[Campo.id] = equipe.id as NSString
        registro[Campo.nome] = equipe.nome as NSString
        registro[Campo.espacoID] = espacoID.uuidString as NSString
        registro[Campo.codigoDeEntrada] = equipe.codigoDeEntrada.map(Self.normalizar) as NSString?
        registro[Campo.configuracoes] = (try? JSONEncoder().encode(equipe.configuracoes)) as NSData?
        return registro
    }

    private func publicarCodigo(_ codigo: String?, para url: URL) async throws {
        guard let codigo else { throw ErroDeEquipeCloudKit.codigoInvalido }
        let registro = CKRecord(recordType: TipoDeRegistro.codigoDeEquipe)
        registro[Campo.codigoDeEntrada] = Self.normalizar(codigo) as NSString
        registro[Campo.urlDoCompartilhamento] = url.absoluteString as NSString
        _ = try await container.publicCloudDatabase.save(registro)
    }

    private func configuracoes(no registro: CKRecord) -> ConfiguracoesDaEquipe {
        guard let dados = registro[Campo.configuracoes] as? Data,
              let configuracoes = try? JSONDecoder().decode(ConfiguracoesDaEquipe.self, from: dados)
        else { return .init() }
        return configuracoes
    }

    private func referenciaDaZona(de equipe: EquipeDisponivel) throws -> CKRecordZone.ID {
        guard let zona = equipe.zonaCloudKit
        else {
            throw ErroDeEquipeCloudKit.equipeAindaLocal
        }
        return CKRecordZone.ID(zoneName: zona)
    }

    private func idDoCompartilhamento(
        de equipe: EquipeDisponivel,
        na zona: CKRecordZone.ID
    ) throws -> CKRecord.ID {
        guard let nome = equipe.compartilhamentoCloudKit else {
            throw ErroDeEquipeCloudKit.equipeAindaLocal
        }
        return CKRecord.ID(recordName: nome, zoneID: zona)
    }
}

enum BancoCloudKitDaEquipe: String {
    case privado
    case compartilhado
}

enum ErroDeEquipeCloudKit: LocalizedError {
    case contaICloudIndisponivel
    case equipeAindaLocal
    case registroDaEquipeInvalido
    case codigoInvalido
    case conviteIndisponivel
    case apenasAdministrador

    var errorDescription: String? {
        switch self {
        case .contaICloudIndisponivel:
            "Entre no iCloud neste Mac para usar equipes compartilhadas."
        case .equipeAindaLocal:
            "Esta equipe ainda não foi publicada no CloudKit."
        case .registroDaEquipeInvalido:
            "O convite não contém uma equipe válida do Papagaio."
        case .codigoInvalido:
            "Não encontramos uma equipe com esse código."
        case .conviteIndisponivel:
            "Não foi possível preparar o convite desta equipe."
        case .apenasAdministrador:
            "Somente quem criou a equipe pode alterar estas configurações."
        }
    }
}
