%{
#include <stdlib.h>
#include <stdio.h>
#include "symtab.h"

unsigned short depth = 0;
symtab * st;
%}
%union {int num; char* string; enum type type;}
%token tMAIN tAO tAF tINT tVOID tIF tWHILE tCONST tEGAL tSOU tADD tMUL tDIV tPO tPF tPV tFL tPRINT tID tNB tDEG tDIF tSUP tINF tSUE tINE tAND tOR
%token <num> tNB
%token <string> tID
%type <num> Valeur Cond Conds
%type <type> Type
%start Main
%%
Main : tMAIN tPO tPF Body ; /* Main */
Func : Type tID tPO Args tPF Body {printf("fin function");};  /* Function */ 
Arg : Type tID ; 
Args : Arg tVIR Args ; 
Type : tINT { $$ = INT; }
     | tVOID { $$ = VOID; };
Body : tAO { depth++; } Insts tAF { remove_depth(st,depth); depth--; }; /* Corps de fonction/structure de contrôle */
Insts: Inst Insts
     | ;
Inst : Decl
     | Aff
     | Print
     | Ctrl ;
Decl: Type tID tPV { add_sym(st,$1,$2,depth); } /* Déclaration sans affectation */
    | Type tID tEGAL Valeur tPV { add_sym(st,$1,$2,depth); /* ASM */ } /* Déclaration avec affectation */
    | tCONST Type tID tEGAL Valeur tPV /*{ valeur dans le code }*/; /* Déclaration de constante */
Aff: tID tEGAL Valeur tPV /*{  } /* Attribution */
   | tID tMUL tEGAL Valeur tPV /*{  } /* Multiplication */
   | tID tDIV tEGAL Valeur tPV /*{  }*/ /* Division */
   | tID tADD tEGAL Valeur tPV /*{  } /* Addition */
   | tID tSOU tEGAL Valeur tPV ; /*{  } /* Soustraction */
Valeur: tNB {  } /* Nombre */
      | tID { get_address(st,$1) } /* Variable */
      | tPO Valeur tPF //{ $$ = $2; } /* Parenthèse */
      | Valeur tADD Valeur //{ $$ = $1 + $3; } /* Addition */
      | Valeur tSOU Valeur //{ $$ = $1 - $3; }/* Soustraction */
      | Valeur tMUL Valeur //{ $$ = $1 * $3; }/* Multiplication */
      | Valeur tDIV Valeur //{ $$ = $1 / $3; }; /* Division */
Print : tPRINT tPO Valeur tPF tPV; //{ printf("%d\n",$3); };
Ctrl  : tIF tPO Conds tPF Body
      | tWHILE tPO Conds tPF Body;
Conds : Conds Sym Conds
      | tPO Conds tPF
      | Cond ;
Sym   : tAND
      | tOR ;
Cond  : Valeur
      | Valeur tDEG Valeur
      | Valeur tDIF Valeur
      | Valeur tSUP Valeur
      | Valeur tSUE Valeur
      | Valeur tINF Valeur
      | Valeur tINE Valeur ;
%%
void yyerror(char *s) { fprintf(stderr, "%s\n", s); exit(1); }
int main(void) {
   st = init_st();
   yyparse();
   printf("YES\n");
   return 0;
}
