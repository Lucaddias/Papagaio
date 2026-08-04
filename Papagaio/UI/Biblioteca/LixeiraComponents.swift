import PapagaioCore
import SwiftUI

/// As duas coleções reais da biblioteca. A lixeira é aberta pelas
/// Configurações, mas continua uma área separada porque não é exclusão
/// definitiva.
enum SecaoDaBiblioteca: String, Identifiable {
    case todos = "Todos os arquivos"
    case lixeira = "Lixeira"

    var id: Self { self }
}

/// Um item recuperável. As ações ficam visíveis no card para seguir o fluxo da
/// referência: restaurar ou apagar definitivamente sem abrir um menu extra.
struct CartaoDaLixeira: View {
    let arquivo: Arquivo
    let emOperacao: Bool
    let aoRestaurar: () -> Void
    let aoPedirExclusaoDefinitiva: () -> Void

    private var titulo: String { arquivo.resumo?.titulo ?? arquivo.titulo }
    private var descricao: String {
        let texto = arquivo.resumo?.visaoGeral
            ?? arquivo.trechos.map(\.texto).joined(separator: " ")
        let limpo = texto.trimmingCharacters(in: .whitespacesAndNewlines)
        return limpo.isEmpty
            ? "Conversa movida para a lixeira. Restaure para acessar transcrição, notas e mídia."
            : limpo
    }

    private var tipoDoItem: (titulo: String, simbolo: String) {
        if arquivo.resumo != nil || !arquivo.trechos.isEmpty {
            return ("TRANSCRIÇÃO", "text.bubble")
        }
        if arquivo.duracao > 0 {
            return ("ÁUDIO", "waveform")
        }
        if !arquivo.notas.isEmpty {
            return ("NOTA", "note.text")
        }
        return ("ARQUIVO", "doc")
    }

    private var dataCurta: String {
        arquivo.criadoEm.formatted(.dateTime.day().month(.abbreviated))
            .uppercased()
            .replacingOccurrences(of: ".", with: "")
    }

    private var duracaoCurta: String {
        let total = Int(max(0, arquivo.duracao.rounded()))
        if total < 60 { return "\(max(1, total)) SEG" }
        let minutos = total / 60
        if minutos < 60 { return "\(minutos) MIN" }
        let horas = minutos / 60
        let resto = minutos % 60
        return resto == 0 ? "\(horas) H" : "\(horas) H \(resto) MIN"
    }

    private var prazoDeExclusao: String {
        guard let apagadoEm = arquivo.apagadoEm,
              let limite = Calendar.current.date(byAdding: .day, value: 30, to: apagadoEm)
        else { return "Exclui em 30 dias" }

        let dias = Calendar.current.dateComponents([.day], from: Date(), to: limite).day ?? 0
        if dias <= 0 { return "Exclui hoje" }
        if dias == 1 { return "Exclui em 1 dia" }
        return "Exclui em \(dias) dias"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top, spacing: 12) {
                Label(tipoDoItem.titulo, systemImage: tipoDoItem.simbolo)
                    .font(.callout.weight(.bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .frame(height: 30)
                    .background(PapagaioTema.destaque, in: RoundedRectangle(cornerRadius: 5, style: .continuous))

                Spacer(minLength: 8)

                HStack(spacing: 16) {
                    if emOperacao {
                        ProgressView()
                            .controlSize(.small)
                            .accessibilityLabel("Atualizando arquivo na lixeira")
                    } else {
                        Button(action: aoRestaurar) {
                            Image(systemName: "arrow.uturn.backward.circle")
                                .font(.system(size: 18, weight: .bold))
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(PapagaioTema.destaqueEscuro)
                        .help("Restaurar")
                        .accessibilityLabel("Restaurar \(titulo)")

                        Button(role: .destructive, action: aoPedirExclusaoDefinitiva) {
                            Image(systemName: "trash")
                                .font(.system(size: 18, weight: .bold))
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(PapagaioTema.perigo)
                        .help("Apagar definitivamente")
                        .accessibilityLabel("Apagar definitivamente \(titulo)")
                    }
                }
            }

            VStack(alignment: .leading, spacing: 12) {
                Text(titulo)
                    .font(.title.weight(.semibold))
                    .foregroundStyle(PapagaioTema.textoSecundario.opacity(0.68))
                    .strikethrough(true, color: PapagaioTema.textoSecundario.opacity(0.68))
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)

                Text(descricao)
                    .font(.body)
                    .foregroundStyle(PapagaioTema.textoSecundario)
                    .lineSpacing(3)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)

            SeparadorPapagaio()

            HStack(spacing: 18) {
                Label(dataCurta, systemImage: "calendar")
                Label(duracaoCurta, systemImage: "clock")

                Spacer(minLength: 8)

                Text(prazoDeExclusao)
                    .font(.callout.weight(.bold))
                    .foregroundStyle(PapagaioTema.perigo)
            }
            .font(.callout.weight(.semibold))
            .foregroundStyle(PapagaioTema.textoSecundario.opacity(0.62))
        }
        .padding(28)
        .frame(maxWidth: .infinity, minHeight: 310, alignment: .topLeading)
        .cartaoPapagaio()
        .opacity(emOperacao ? 0.72 : 1)
        .accessibilityElement(children: .contain)
    }
}

struct TarefaNaLixeira: Identifiable, Codable, Equatable {
    let id: UUID
    let arquivoID: ArquivoID
    let conversaTitulo: String
    let tarefa: TarefaDaConversa
    let apagadoEm: Date

    init(
        id: UUID = UUID(),
        arquivoID: ArquivoID,
        conversaTitulo: String,
        tarefa: TarefaDaConversa,
        apagadoEm: Date = Date()
    ) {
        self.id = id
        self.arquivoID = arquivoID
        self.conversaTitulo = conversaTitulo
        self.tarefa = tarefa
        self.apagadoEm = apagadoEm
    }
}

enum LixeiraDeTarefas {
    static func itens() -> [TarefaNaLixeira] {
        guard let dados = UserDefaults.standard.data(forKey: chave),
              let itens = try? JSONDecoder().decode([TarefaNaLixeira].self, from: dados)
        else { return [] }
        return itens.sorted { $0.apagadoEm > $1.apagadoEm }
    }

    static func mover(_ tarefa: TarefaDaConversa, arquivoID: ArquivoID, conversaTitulo: String) {
        var atuais = itens()
        guard !atuais.contains(where: { $0.arquivoID == arquivoID && $0.tarefa.id == tarefa.id }) else { return }
        atuais.append(TarefaNaLixeira(arquivoID: arquivoID, conversaTitulo: conversaTitulo, tarefa: tarefa))
        salvar(atuais)
    }

    static func restaurar(_ item: TarefaNaLixeira, arquivos: [Arquivo]) {
        guard let arquivo = arquivos.first(where: { $0.id == item.arquivoID }) else { return }
        var tarefas = TarefasGeraisStore.carregar(arquivo)
        if !tarefas.contains(where: { $0.id == item.tarefa.id }) {
            tarefas.append(item.tarefa)
            TarefasGeraisStore.salvar(tarefas, para: item.arquivoID)
        }
        remover(item)
    }

    static func remover(_ item: TarefaNaLixeira) {
        salvar(itens().filter { $0.id != item.id })
    }

    static func restaurarTudo(arquivos: [Arquivo]) {
        itens().forEach { restaurar($0, arquivos: arquivos) }
    }

    static func esvaziar() {
        UserDefaults.standard.removeObject(forKey: chave)
    }

    private static func salvar(_ itens: [TarefaNaLixeira]) {
        guard let dados = try? JSONEncoder().encode(itens) else { return }
        UserDefaults.standard.set(dados, forKey: chave)
    }

    private static let chave = "tarefasNaLixeira"
}

struct CartaoDaTarefaNaLixeira: View {
    let item: TarefaNaLixeira
    let aoRestaurar: () -> Void
    let aoApagarDefinitivamente: () -> Void

    private var prazoDeExclusao: String {
        guard let limite = Calendar.current.date(byAdding: .day, value: 30, to: item.apagadoEm) else {
            return "Exclui em 30 dias"
        }
        let dias = Calendar.current.dateComponents([.day], from: Date(), to: limite).day ?? 0
        if dias <= 0 { return "Exclui hoje" }
        if dias == 1 { return "Exclui em 1 dia" }
        return "Exclui em \(dias) dias"
    }

    private var dataCurta: String {
        (item.tarefa.prazo ?? item.apagadoEm)
            .formatted(.dateTime.day().month(.abbreviated))
            .uppercased()
            .replacingOccurrences(of: ".", with: "")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top, spacing: 12) {
                Label("TAREFA", systemImage: "checklist")
                    .font(.callout.weight(.bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .frame(height: 30)
                    .background(PapagaioTema.destaque, in: RoundedRectangle(cornerRadius: 5, style: .continuous))

                Spacer(minLength: 8)

                HStack(spacing: 16) {
                    Button(action: aoRestaurar) {
                        Image(systemName: "arrow.uturn.backward.circle")
                            .font(.system(size: 18, weight: .bold))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(PapagaioTema.destaqueEscuro)
                    .help("Restaurar tarefa")

                    Button(role: .destructive, action: aoApagarDefinitivamente) {
                        Image(systemName: "trash")
                            .font(.system(size: 18, weight: .bold))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(PapagaioTema.perigo)
                    .help("Apagar tarefa definitivamente")
                }
            }

            VStack(alignment: .leading, spacing: 12) {
                Text(item.tarefa.titulo)
                    .font(.title.weight(.semibold))
                    .foregroundStyle(PapagaioTema.textoSecundario.opacity(0.68))
                    .strikethrough(true, color: PapagaioTema.textoSecundario.opacity(0.68))
                    .lineLimit(2)

                Text("Tarefa removida de \(item.conversaTitulo). Restaure para voltar ao painel de tarefas dessa conversa.")
                    .font(.body)
                    .foregroundStyle(PapagaioTema.textoSecundario)
                    .lineSpacing(3)
                    .lineLimit(3)
            }

            Spacer(minLength: 0)

            SeparadorPapagaio()

            HStack(spacing: 18) {
                Label(dataCurta, systemImage: "calendar")
                Label(item.tarefa.responsavel?.isEmpty == false ? item.tarefa.responsavel! : "SEM RESPONSÁVEL", systemImage: "person")

                Spacer(minLength: 8)

                Text(prazoDeExclusao)
                    .font(.callout.weight(.bold))
                    .foregroundStyle(PapagaioTema.perigo)
            }
            .font(.callout.weight(.semibold))
            .foregroundStyle(PapagaioTema.textoSecundario.opacity(0.62))
        }
        .padding(28)
        .frame(maxWidth: .infinity, minHeight: 310, alignment: .topLeading)
        .cartaoPapagaio()
        .accessibilityElement(children: .contain)
    }
}

struct AcoesDaLixeira: View {
    let temArquivos: Bool
    let aoRestaurarTudo: () -> Void
    let aoEsvaziar: () -> Void

    var body: some View {
        HStack(spacing: 16) {
            Button("Restaurar Tudo", systemImage: "arrow.counterclockwise", action: aoRestaurarTudo)
                .buttonStyle(BotaoDeContornoPapagaio())
                .disabled(!temArquivos)
                .help("Restaurar todos os arquivos da lixeira")

            Button("Esvaziar Lixeira", systemImage: "trash.square", role: .destructive, action: aoEsvaziar)
                .font(.body.weight(.semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 18)
                .frame(minHeight: 44)
                .background(PapagaioTema.destaque, in: Capsule())
                .buttonStyle(.plain)
                .disabled(!temArquivos)
                .opacity(temArquivos ? 1 : 0.45)
                .help("Apagar definitivamente todos os arquivos da lixeira")
        }
    }
}
