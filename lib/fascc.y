%{
#include <stdlib.h>
#include <stdio.h>

#include "type.h"
#include "function.h"
#include "asmtab.h"
#include "condtab.h"
#include "funtab.h"
#include "symtab.h"

int yylex();
void yyerror(const char *s);

unsigned int depth = 0; // Profondeur courante du programme
unsigned int offset = 0; // Décalage des variables temporaires
unsigned int fun_offset = 0; // Décalage des arguments de fonction
unsigned int ret_add = 0; // Adresse de retour de function
unsigned int addr_tmp = 0; // Adresse temporaire utilisée
unsigned int arg_count = 0; // Adresse du prochain argument d'une fonction

function* fun; // Création de fonction
function* call;// Appel de fonction

symtab * st; // Tableau de symboles
condtab * ct; // Pile de structure de contrôle
funtab * ft; // Tableau de fonctions
asmtab * at; // Tableau d'instructions

// Fonction de choix de l'adresse temporaire de retour
unsigned int tmp_add(unsigned int left, unsigned int right) {
   unsigned int left_tmp = is_tmp(st,left);
   unsigned int right_tmp = is_tmp(st,right);
   if (left_tmp) {
      if (right_tmp && offset >= 1) {
         offset--;
      }
      return left;
   } else if (right_tmp) {
      return right;
   }
   return get_tmp(st,offset++);
}

%}
%union {int num; char* string; enum type type; enum op op;}
%token tAO tAF tINT tVOID tIF tWHILE tCONST tEGAL tSOU tADD tMUL tDIV tPO tPF tPV tFL tPRINT tDEG tDIF tSUP tINF tSUE tINE tAND tOR tVIR tRET
%token <num> tNB
%token <string> tID tMAIN
%type <num> Valeur Cond Conds
%type <type> Type MType
%type <op> Sym
%right tEGAL
%left tADD tSOU
%left tMUL tDIV
%start Prg
%%
Prg  : Func Prg
     | Main { YYACCEPT; };
Main : MType tMAIN { set_main_asm(at,get_last_line(at)); set_main_fun(ft,get_last_line(at),$1); }
     tPO tPF Body ; /* Main */
MType: tINT { $$ = INT; }
     | tVOID { $$ = VOID; }
     | { $$ = INT; };
Func : Type tID { fun = init_fun($2,get_last_line(at),$1); } tPO DArgs tPF { add_fun(ft,fun); } Body { add_asm(at,RET,0,0,0); 
     //TODO reduce return 
     };  /* Fonction */
DArgs: DArg tVIR DArgs
     | DArg
     | ;
DArg : Type tID { add_arg(fun,$2,$1); add_sym(st,$1,$2,1); };
Type : tINT { $$ = INT; }
     | tVOID { $$ = VOID; };
Body : tAO { depth++; } Insts tAF { remove_depth(st,depth); depth--; offset=0;} /* Corps de fonction/structure de contrôle */;
Insts: Inst Insts
     | ;
Inst : Decl tPV
     | Aff tPV
     | Call tPV
     | Return tPV
     | Print tPV
     | Ctrl ;
Decl: Type tID { add_sym(st,$1,$2,depth); } /* Déclaration sans affectation */
    | Type tID tEGAL Valeur { add_sym(st,$1,$2,depth); offset=0; } /* Déclaration avec affectation */
    | tCONST Type tID tEGAL Valeur /*{ valeur dans le code }*/; /* Déclaration de constante */
Aff: tID tEGAL Valeur { add_asm(at,COP,get_sym_address(st,$1),$3,0); reduce_cop(at); offset=0; } /* Attribution */
   | tID tMUL tEGAL Valeur { addr_tmp = get_sym_address(st,$1); add_asm(at,MUL,addr_tmp,addr_tmp,$4); offset=0; } /* Multiplication */
   | tID tDIV tEGAL Valeur { addr_tmp = get_sym_address(st,$1); add_asm(at,DIV,addr_tmp,addr_tmp,$4); offset=0; } /* Division */
   | tID tADD tEGAL Valeur { addr_tmp = get_sym_address(st,$1); add_asm(at,ADD,addr_tmp,addr_tmp,$4); offset=0; } /* Addition */
   | tID tSOU tEGAL Valeur { addr_tmp = get_sym_address(st,$1); add_asm(at,SOU,addr_tmp,addr_tmp,$4); offset=0; } /* Soustraction */;
Valeur: tNB { addr_tmp = get_tmp(st,offset++); add_asm(at,AFC,addr_tmp,$1,0); $$ = addr_tmp; } /* Nombre */
      | tID { $$ = get_sym_address(st,$1); } /* Variable */
      | Call { 
      if (call->t == VOID)
         yyerror("CANNOT GET VALUE FROM VOID FUNCTION");
      addr_tmp = get_tmp(st,offset++);
      add_asm(at,COP,addr_tmp,offset+1,0);
      $$ = addr_tmp;
      }
      | tPO Valeur tPF { $$ = $2; } /* Parenthèses */
      | Valeur tMUL Valeur { addr_tmp = tmp_add($1,$3); add_asm(at,MUL,addr_tmp,$1,$3); $$ = addr_tmp; } /* Multiplication */
      | Valeur tDIV Valeur { addr_tmp = tmp_add($1,$3); add_asm(at,DIV,addr_tmp,$1,$3); $$ = addr_tmp; } /* Division */
      | Valeur tADD Valeur { addr_tmp = tmp_add($1,$3); add_asm(at,ADD,addr_tmp,$1,$3); $$ = addr_tmp; } /* Addition */
      | Valeur tSOU Valeur { addr_tmp = tmp_add($1,$3); add_asm(at,SOU,addr_tmp,$1,$3); $$ = addr_tmp; }; /* Soustraction */
Call  : tID tPO { fun_offset = offset; } Args tPF { ret_add = get_fun(ft,$1,call);
      if (ret_add < 0) 
         yyerror("UNDEFINED FUNCTION");
      if (arg_count != call->argc)
         yyerror("WRONG NUMBER OF ARGUMENTS");
      add_asm(at,CLL,get_tmp(st,offset),get_last_line(at)+1,call->add);
      arg_count=0;
      };
Args  : Arg tVIR Args
      | Arg
      | ;
Arg   : Valeur {
      if (is_tmp(st,$1)) {
         offset--;
      }
      add_asm(at,COP,get_tmp(st,fun_offset+2),$1,0);
      //TODO reduce_cop(at);
      arg_count++;
      fun_offset++;
      };
Return: tRET Valeur {
      if (fun->t == VOID)
         yyerror("RETURN WITH VALUE IN VOID FUNCTION");
      add_asm(at,COP,0,$2,0);
      reduce_cop(at);
      add_asm(at,RET,0,0,0);
      }
      | tRET {
      if (fun->t != VOID) 
         yyerror("RETURN WITHOUT VALUE IN NON-VOID FUNCTION");
      add_asm(at,RET,0,0,0);
      }
Print : tPRINT tPO Valeur tPF { add_asm(at,PRI,$3,0,0); offset=0; };
Ctrl  : tIF tPO Conds tPF { push_cond(ct,get_last_line(at)); add_asm(at,JMF,$3,0,0); offset=0;} Body { jump_if(at,pop_cond(ct),get_last_line(at)); }
      | tWHILE tPO { push_cond(ct,get_last_line(at)); } Conds tPF { push_cond(ct,get_last_line(at)); add_asm(at,JMF,$4,0,0); offset=0; } Body { add_asm(at,JMP,0,0,0); jump_while(at,pop_cond(ct),pop_cond(ct),get_last_line(at));};
Conds : Conds Sym Conds { addr_tmp = tmp_add($1,$3); add_asm(at,$2,addr_tmp,$1,$3); $$ = addr_tmp; }
      | tPO Conds tPF { $$ = $2; }
      | Cond { $$ = $1; };
Sym   : tAND { $$ = AND; }
      | tOR { $$ = OR; };
Cond  : Valeur { $$ = $1; }
      | Valeur tDEG Valeur { addr_tmp = tmp_add($1,$3); add_asm(at,EQU,addr_tmp,$1,$3); $$ = addr_tmp; }
      | Valeur tDIF Valeur { addr_tmp = tmp_add($1,$3); add_asm(at,EQU,addr_tmp,$1,$3); add_asm(at,NOT,addr_tmp,addr_tmp,0); $$ = addr_tmp; }
      | Valeur tSUP Valeur { addr_tmp = tmp_add($1,$3); add_asm(at,SUP,addr_tmp,$1,$3); $$ = addr_tmp; }
      | Valeur tSUE Valeur { addr_tmp = tmp_add($1,$3); add_asm(at,INF,addr_tmp,$1,$3); add_asm(at,NOT,addr_tmp,addr_tmp,0); $$ = addr_tmp; }
      | Valeur tINF Valeur { addr_tmp = tmp_add($1,$3); add_asm(at,INF,addr_tmp,$1,$3); $$ = addr_tmp; }
      | Valeur tINE Valeur { addr_tmp = tmp_add($1,$3); add_asm(at,SUP,addr_tmp,$1,$3); add_asm(at,NOT,addr_tmp,addr_tmp,0); $$ = addr_tmp; };
%%
void yyerror(const char *s) { fprintf(stderr, "%s\n", s); exit(1); }
int main(int argc, char** argv) {
   st = init_st();
   ct = init_ct();
   ft = init_ft();
   at = init_at();
   call = malloc(sizeof(function));
   yyparse();
   FILE* out = fopen("./out","w");
   export_asm(at,out);
   return 0;
}
