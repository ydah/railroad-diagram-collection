%token WORD "`word'"
%token LT "<"
%token CLASS "'class'"
%%
start /* rule comments are valid */: option('\n') { } items '>' ;
items: WORD | items ',' WORD ;
option_user_named: WORD ;
%%
