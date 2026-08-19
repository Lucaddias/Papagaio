import Foundation

/// Concordância de gênero e número para os rótulos de pessoas.
///
/// "Entrevistado: Ana Silva" está errado em português, e o app escrevia isso em
/// toda ficha de toda conversa com uma mulher — que é a maioria das entrevistas
/// de muita gente. Rótulo errado não é detalhe de estilo: é o app se dirigindo
/// à pessoa entrevistada pelo gênero errado, na tela que existe justamente para
/// registrar quem ela é.
///
/// A inferência é por nome, e portanto é um palpite. É um palpite bom o
/// bastante — o primeiro nome carrega gênero de forma bem regular em português
/// — e o custo do erro é baixo e visível: a pessoa lê o rótulo e corrige o nome
/// se quiser. O que não dava para manter era o masculino fixo, que erra sempre
/// que a entrevistada é mulher, e nunca dá sinal disso.
enum Genero {
    case feminino
    case masculino
}

/// Nomes masculinos terminados em "a".
///
/// A regra "termina em A, é feminino" acerta quase sempre em português, e estes
/// são os casos comuns em que ela erra. Lista curta de propósito: cada entrada
/// aqui é uma aposta de que o nome nunca é feminino, e nomes ambíguos ficam de
/// fora para cair na regra geral.
private let masculinosTerminadosEmA: Set<String> = [
    "luca", "lucca", "nicola", "juca", "gaspara", "elia", "atila", "atilla",
    "buda", "yuudai", "kenta", "ryota", "akira", "yoshua", "joshua", "noa",
    "barnaba", "iracema-filho",
]

/// Nomes femininos que **não** terminam em "a".
///
/// O outro lado do mesmo problema: sem esta lista, Beatriz, Carmen e Raquel
/// entravam como masculinas — e são nomes comuns demais para deixar errado.
private let femininosNaoTerminadosEmA: Set<String> = [
    "beatriz", "bia", "ines", "carmen", "carmem", "raquel", "isabel", "ester",
    "esther", "miriam", "miriã", "abigail", "rute", "rebeca", "jaqueline",
    "caroline", "carolines", "eloise", "heloise", "denise", "elis", "alice",
    "ellen", "helen", "karen", "kelen", "cristiane", "cristine", "adriane",
    "eliane", "juliane", "luciane", "rosane", "simone", "ivone", "iracy",
    "nancy", "wendy", "mary", "kelly", "shirley", "sally", "grace", "joyce",
    "iris", "doris", "lourdes", "mercedes", "solange", "consuelo", "conceicao",
    "assuncao", "encarnacao", "sol", "flor", "estrela-do-mar", "noemi",
    "naomi", "ruth", "judith", "edith", "elizabeth", "elisabeth", "meire",
    "cleide", "gleide", "neide", "zeide", "aparecida-do-carmo",
]

/// O gênero provável de quem tem este nome.
///
/// Olha só o primeiro nome: é ele que carrega o gênero, e sobrenome de família
/// não varia com quem o usa.
func generoDoNome(_ nome: String) -> Genero {
    let primeiro = nome
        .split(whereSeparator: \.isWhitespace)
        .first
        .map(String.init) ?? nome

    let limpo = primeiro
        .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
        .trimmingCharacters(in: .punctuationCharacters)

    guard !limpo.isEmpty else { return .masculino }

    if femininosNaoTerminadosEmA.contains(limpo) { return .feminino }
    if masculinosTerminadosEmA.contains(limpo) { return .masculino }

    // "Ana", "Mariana", "Letícia" — e também "Andréa", já sem o acento aqui.
    if limpo.hasSuffix("a") { return .feminino }

    return .masculino
}

/// O gênero de um grupo, para efeito de concordância.
///
/// Português usa o masculino no plural misto — um homem numa sala de dez
/// mulheres já torna o grupo "entrevistados". Só grupo inteiramente feminino
/// leva o feminino, e é exatamente isso que esta função devolve.
func generoDoGrupo(_ nomes: [String]) -> Genero {
    guard !nomes.isEmpty else { return .masculino }
    return nomes.allSatisfy { generoDoNome($0) == .feminino } ? .feminino : .masculino
}

/// "Entrevistado", "Entrevistada", "Entrevistados" ou "Entrevistadas".
func rotuloDeEntrevistados(_ nomes: [String]) -> String {
    flexionar(
        singularMasculino: "Entrevistado",
        singularFeminino: "Entrevistada",
        pluralMasculino: "Entrevistados",
        pluralFeminino: "Entrevistadas",
        para: nomes
    )
}

/// "Entrevistador", "Entrevistadora", "Entrevistadores" ou "Entrevistadoras".
func rotuloDeEntrevistadores(_ nomes: [String]) -> String {
    flexionar(
        singularMasculino: "Entrevistador",
        singularFeminino: "Entrevistadora",
        pluralMasculino: "Entrevistadores",
        pluralFeminino: "Entrevistadoras",
        para: nomes
    )
}

/// Sem nome nenhum, o rótulo fica no masculino singular — é a forma neutra que
/// as telas de lacuna usam ("Entrevistado não informado").
private func flexionar(
    singularMasculino: String,
    singularFeminino: String,
    pluralMasculino: String,
    pluralFeminino: String,
    para nomes: [String]
) -> String {
    let feminino = generoDoGrupo(nomes) == .feminino
    if nomes.count > 1 {
        return feminino ? pluralFeminino : pluralMasculino
    }
    return feminino ? singularFeminino : singularMasculino
}
