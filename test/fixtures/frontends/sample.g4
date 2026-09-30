parser grammar Sample;
options { tokenVocab = SampleLexer; }
start: values+=WORD (',' WORD)* '>'? EOF # Root;
lexer grammar SampleLexer;
WORD: 'word';
GT: '>' -> mode(AFTER);
mode AFTER;
SPACE: [ \t]+ -> skip;
