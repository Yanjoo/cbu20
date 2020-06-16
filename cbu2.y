%{
#include <stdio.h>
#include <string.h>
#include <stdlib.h>

#define DEBUG   0

#define    MAXSYM   100
#define    MAXSYMLEN   20
#define    MAXTSYMLEN   15
#define    MAXTSYMBOL   MAXSYM/2

#define STMTLIST 500

typedef struct nodeType {
   int token;
   int tokenval;
   struct nodeType *son;
   struct nodeType *brother;
   } Node;

#define YYSTYPE Node*
   
int tsymbolcnt=0;
int errorcnt=0;

FILE *yyin;
FILE *fp;

extern char symtbl[MAXSYM][MAXSYMLEN];
extern int maxsym;
extern int lineno;

int stack[500];
int top;
int cnt;
int outno;
int loopno;

void DFSTree(Node*);
Node * MakeOPTree(int, Node*, Node*);
Node * MakeNode(int, int);
Node * MakeListTree(Node*, Node*);
void codegen(Node* );
void prtcode(int, int);
void push(int);
void pop();

void   dwgen();
int   gentemp();
void   assgnstmt(int, int);
void   numassgn(int, int);
void   addstmt(int, int, int);
void   substmt(int, int, int);
int      insertsym(char *);
void    printLabel();
%}

%token   ADD SUB ASSGN ID NUM STMTEND START END ID2 ID3 MUL DIV IF ELSE WHILE FIN DONE LT GT LE GE EQ NE AA SA MA DA
%right ASSGN
%left ADD SUB
%left MUL DIV MOD

%%
program   	: 	START stmt_list END   { if (errorcnt==0) {codegen($2); dwgen();} }
      		;

stmt_list 	: 	stmt_list stmt    	{$$=MakeListTree($1, $2);}
      		|   stmt         		{$$=MakeListTree(NULL, $1);}
      		|   error STMTEND   	{ errorcnt++; yyerrok;}
      		;

stmt  	:   ID ASSGN expr STMTEND   { $1->token = ID2; $$=MakeOPTree(ASSGN, $1, $3);}
      	|   IF condition stmt_list FIN { $$=MakeOPTree(IF, $2, $3);}
	  	|	WHILE condition stmt_list DONE { $$ = MakeOPTree(WHILE, $2, $3); }
		|	ID AA expr STMTEND { $1->token = ID3; $$=MakeOPTree(AA, $1, $3); }
		|	ID SA expr STMTEND { $1->token = ID3; $$=MakeOPTree(SA, $1, $3); }
		|	ID MA expr STMTEND { $1->token = ID3; $$=MakeOPTree(MA, $1, $3); }
		|	ID DA expr STMTEND { $1->token = ID3; $$=MakeOPTree(DA, $1, $3); }
      	;


condition 	: 	expr EQ expr { $$ = MakeOPTree(EQ, $1, $3); }
      		|   expr NE expr { $$ = MakeOPTree(NE, $1, $3); }
      		|   expr LT expr { $$ = MakeOPTree(LT, $1, $3); }
     		|   expr GT expr { $$ = MakeOPTree(GT, $1, $3); }
      		|   expr LE expr { $$ = MakeOPTree(LE, $1, $3); }
      		|   expr GE expr { $$ = MakeOPTree(GE, $1, $3); }
      		;

expr  	:   expr ADD est   { $$=MakeOPTree(ADD, $1, $3); }
      	|   expr SUB est   { $$=MakeOPTree(SUB, $1, $3); }
      	|   est
      	;

est     :   est MUL term   	{ $$ = MakeOPTree(MUL, $1, $3); }
      	|   est DIV term   	{ $$ = MakeOPTree(DIV, $1, $3); }
      	|   term
      	;

term   	:   ID      	{ /* ID node is created in lex */ }
      	|   NUM      	{ /* NUM node is created in lex */ }
      	;


%%
int main(int argc, char *argv[]) 
{
   printf("\nproject CBU compiler\n");
   printf("Made by Hanju Lee (2015041075), 2020.\n");
   
   if (argc == 2)
      yyin = fopen(argv[1], "r");
   else {
      printf("Usage: cbu inputfile\noutput file is 'a.asm'\n");
      return(0);
      }
      
   fp=fopen("a.asm", "w");
   
   yyparse();
   
   fclose(yyin);
   fclose(fp);

   if (errorcnt==0) 
      { printf("Successfully compiled. Assembly code is in 'a.asm'.\n");}
}

yyerror(s)
char *s;
{
   printf("%s (line %d)\n", s, lineno);
}


Node * MakeOPTree(int op, Node* operand1, Node* operand2)
{
Node * newnode;

   newnode = (Node *)malloc(sizeof (Node));
   newnode->token = op;
   newnode->tokenval = op;
   newnode->son = operand1;
   newnode->brother = NULL;
   operand1->brother = operand2;
   return newnode;
}

Node * MakeNode(int token, int operand)
{
Node * newnode;

   newnode = (Node *) malloc(sizeof (Node));
   newnode->token = token;
   newnode->tokenval = operand; 
   newnode->son = newnode->brother = NULL;
   return newnode;
}

Node * MakeListTree(Node* operand1, Node* operand2)
{
Node * newnode;
Node * node;

   if (operand1 == NULL){
      newnode = (Node *)malloc(sizeof (Node));
      newnode->token = newnode-> tokenval = STMTLIST;
      newnode->son = operand2;
      newnode->brother = NULL;
      return newnode;
      }
   else {
      node = operand1->son;
      while (node->brother != NULL) node = node->brother;
      node->brother = operand2;
      return operand1;
      }
}

void codegen(Node * root)
{
   DFSTree(root);
}

void DFSTree(Node * n)
{
   if (n==NULL) return;
   if (n->token == WHILE)
		fprintf(fp, "LABEL LOOP%d\n", ++loopno);
   DFSTree(n->son);
   prtcode(n->token, n->tokenval);
   DFSTree(n->brother);
}

void prtcode(int token, int val)
{
   	switch (token) {
   	case ID:
      	fprintf(fp,"RVALUE %s\n", symtbl[val]);
      	break;
   	case ID2:
      	fprintf(fp, "LVALUE %s\n", symtbl[val]);
      	break;
	case ID3:
		fprintf(fp, "LVALUE %s\n", symtbl[val]);
		fprintf(fp, "RVALUE %s\n", symtbl[val]);
		break;
   	case NUM:
      	fprintf(fp, "PUSH %d\n", val);
      	break;
   	case ADD:
      	fprintf(fp, "+\n");
      	break;
   	case SUB:
      	fprintf(fp, "-\n");
      	break;
   	case MUL:
      	fprintf(fp, "*\n");
      	break;
   	case DIV:
      	fprintf(fp, "/\n");
      	break;
   	case IF:
      	fprintf(fp, "LABEL OUT%d\n", stack[top]);
		//outno++;
		pop();
      	break;
   	case EQ:
		cnt++;
   		push(cnt);
      	fprintf(fp, "-\n");
      	fprintf(fp, "GOTRUE OUT%d\n", stack[top]);
      	break;
   	case NE:
		cnt++;
		push(cnt);
      	fprintf(fp, "-\n");
      	fprintf(fp, "GOFALSE OUT%d\n", stack[top]);
      	break;
	case LT:
		cnt++;
		push(cnt);
		fprintf(fp, "-\n");
		fprintf(fp, "COPY\n");
		fprintf(fp, "GOPLUS OUT%d\n", stack[top]);
		fprintf(fp, "GOFALSE OUT%d\n", stack[top]);
		break;
	case GT:
		cnt++;
		push(cnt);
		fprintf(fp, "-\n");
		fprintf(fp, "COPY\n");
		fprintf(fp, "GOMINUS OUT%d\n", stack[top]);
		fprintf(fp, "GOFALSE OUT%d\n", stack[top]);
		break;
	case LE:
		cnt++;
		push(cnt);
		fprintf(fp, "-\n");
		fprintf(fp, "GOPLUS OUT%d\n", stack[top]);
		break;
	case GE:
		cnt++;
		push(cnt);
		fprintf(fp, "-\n");
		fprintf(fp, "GOMINUS OUT%d\n", stack[top]);
		break;
	case WHILE:
		fprintf(fp, "GOTO LOOP%d\n", stack[top]);
		fprintf(fp, "LABEL OUT%d\n", stack[top]);
		//loopno++;
		//outno++;
		pop();
		break;
   case ASSGN:
      fprintf(fp, ":=\n");
      break;
	case AA:
		fprintf(fp, "+\n");
		fprintf(fp, ":=\n");
		break;
	case SA:
		fprintf(fp, "-\n");
		fprintf(fp, ":=\n");
		break;
	case MA:
		fprintf(fp, "*\n");
		fprintf(fp, ":=\n");
		break;
	case DA:
		fprintf(fp, "/\n");
		fprintf(fp, ":=\n");
		break;
   case STMTLIST:
   default:
      break;
   };
}

/* int gentemp()
{
char buffer[MAXTSYMLEN];
char tempsym[MAXSYMLEN]="TTCBU";

   tsymbolcnt++;
   if (tsymbolcnt > MAXTSYMBOL) printf("temp symbol overflow\n");
   itoa(tsymbolcnt, buffer, 10);
   strcat(tempsym, buffer);
   return( insertsym(tempsym) ); // Warning: duplicated symbol is not checked for lazy implementation
} */

void dwgen()
{
int i;
   fprintf(fp, "HALT\n");
   fprintf(fp, "$ -- END OF EXECUTION CODE AND START OF VAR DEFINITIONS --\n");

// Warning: this code should be different if variable declaration is supported in the language 
   for(i=0; i<maxsym; i++) 
      fprintf(fp, "DW %s\n", symtbl[i]);
   fprintf(fp, "END\n");
}

void push(num)
int num;
{
	stack[++top] = num;
}
void pop()
{
	top--;
}