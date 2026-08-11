import Foundation

/// Gramática GBNF que força o formato de `Resumo` na decodificação.
///
/// Por que gramática e não só instrução no prompt: o `llama.cpp` restringe o
/// espaço de tokens **a cada passo**, então a saída não pode sair do formato.
/// Pedir JSON no prompt e torcer é o que produz o JSON malformado que o
/// reprompt teria que consertar. Ver skill `papagaio-summarization`.
///
/// `@Generable`/`@Guide` não existem aqui — são exclusivos do `FoundationModels`
/// da Apple, que está fora da stack (D-0.5).
public enum GramaticaDoResumo {
    public static let gbnf = #"""
    root ::= "{" ws "\"titulo\":" ws string "," ws "\"visaoGeral\":" ws string "," ws "\"temas\":" ws temas "," ws "\"citacoes\":" ws citacoes "," ws "\"proximosPassos\":" ws passos ws "}"
    temas ::= "[" ws (tema (ws "," ws tema)*)? ws "]"
    tema ::= "{" ws "\"titulo\":" ws string "," ws "\"detalhe\":" ws string ws "}"
    citacoes ::= "[" ws (citacao (ws "," ws citacao)*)? ws "]"
    citacao ::= "{" ws "\"texto\":" ws string "," ws "\"speaker\":" ws opcional "," ws "\"start\":" ws numeroOuNulo ws "}"
    passos ::= "[" ws (passo (ws "," ws passo)*)? ws "]"
    passo ::= "{" ws "\"descricao\":" ws string "," ws "\"responsavel\":" ws opcional ws "}"
    opcional ::= string | "null"
    numeroOuNulo ::= numero | "null"
    string ::= "\"" char* "\"" ws
    char ::= [^"\\] | "\\" (["\\bfnrt] | "u" [0-9a-fA-F] [0-9a-fA-F] [0-9a-fA-F] [0-9a-fA-F])
    numero ::= "-"? [0-9]+ ("." [0-9]+)? ws
    ws ::= [ \t\n]*
    """#

    /// Descrição do formato para o prompt. A gramática garante a **sintaxe**;
    /// isto orienta o **conteúdo**.
    public static let descricaoDoFormato = """
    Responda SOMENTE com um objeto JSON com exatamente estas chaves:
    - "titulo": título curto da reunião
    - "visaoGeral": parágrafo único resumindo a reunião inteira
    - "temas": lista de {"titulo", "detalhe"}
    - "citacoes": no máximo 3 frases marcantes da conversa. Cada "texto" deve
      ser uma sequência LITERAL de 8 a 32 palavras de UMA linha da transcrição,
      sem paráfrase e sem muletas como "éé", "ah", "hum", "putz", "tipo" ou
      "né". Escolha decisões, aprendizados, posicionamentos ou ideias memoráveis;
      nunca frases genéricas. Copie o horário [mm:ss] dessa mesma linha em
      "start" (em segundos). Se não houver frase realmente marcante, use [].
    - "proximosPassos": lista de {"descricao", "responsavel"}
    Use "null" quando não souber o falante ou o responsável.
    """
}
