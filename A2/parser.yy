%skeleton "lalr1.cc"
%require  "3.0.1"

%defines 
%define api.namespace {IPL}
%define api.parser.class {Parser}

%locations

%define parse.trace

%code requires{

    #include "ast.hh"
    class Node{ 
    public:
    
    string name;
    int size; 
    string type; 
    string text;
    abstract_astnode* ast;
    bool iszero = false;
    bool lvalue = true;
    };

    

    #include "SymbolTable.hh"

   namespace IPL {
      class Scanner;
   }

   #include "location.hh"

    

  // # ifndef YY_NULLPTR
  // #  if defined __cplusplus && 201103L <= __cplusplus
  // #   define YY_NULLPTR nullptr
  // #  else
  // #   define YY_NULLPTR 0
  // #  endif
  // # endif

}



%printer { std::cerr << $$; } STRUCT
%printer { std::cerr << $$; } IDENTIFIER
%printer { std::cerr << $$; } VOID
%printer { std::cerr << $$; } FLOAT
%printer { std::cerr << $$; } INT_CONSTANT
%printer { std::cerr << $$; } RETURN
%printer { std::cerr << $$; } OR_OP
%printer { std::cerr << $$; } AND_OP
%printer { std::cerr << $$; } EQ_OP
%printer { std::cerr << $$; } NE_OP
%printer { std::cerr << $$; } LE_OP
%printer { std::cerr << $$; } GE_OP
%printer { std::cerr << $$; } PTR_OP
%printer { std::cerr << $$; } INC_OP
%printer { std::cerr << $$; } FLOAT_CONSTANT
%printer { std::cerr << $$; } STRING_LITERAL
%printer { std::cerr << $$; } IF
%printer { std::cerr << $$; } ELSE
%printer { std::cerr << $$; } WHILE
%printer { std::cerr << $$; } FOR


%parse-param { Scanner  &scanner  }
%locations
%code{


   #include <iostream>
    #include <cstdlib>
    #include <fstream>
    #include <string>
    #include <stack>
    #include <map>

    #include "scanner.hh"

        
   int nodeCount = 0;

    void printAst(const char *astname, const char *fmt, ...) // fmt is a format string that tells about the type of the arguments.
{   
	typedef vector<abstract_astnode *>* pv;
	va_list args;
	va_start(args, fmt);
	if ((astname != NULL) && (astname[0] != '\0'))
	{
		cout << "{ ";
		cout << "\"" << astname << "\"" << ": ";
	}
	cout << "{" << endl;
	while (*fmt != '\0')
	{
		if (*fmt == 'a')
		{
            abstract_astnode *a = va_arg(args, abstract_astnode *);
			char * field = va_arg(args, char *);
			cout << "\"" << field << "\": " << endl;
			
			a->print(0);
		}
		else if (*fmt == 's')
		{
            char *str = va_arg(args, char *);
			char * field = va_arg(args, char *);
			cout << "\"" << field << "\": ";

            if(str[0] == '"'){
                cout << str << endl;
            }
            else{
                cout << "\"" << str << "\"" << endl;
            }
			
		}
		else if (*fmt == 'i')
		{
            int i = va_arg(args, int);
			char * field = va_arg(args, char *);
			cout << "\"" << field << "\": ";

			cout << i;
		}
		else if (*fmt == 'f')
		{
            double f = va_arg(args, double);
            char * field = va_arg(args, char *);
			cout << "\"" << field << "\": ";
			cout << f;
		}
		else if (*fmt == 'l')
		{
            pv f =  va_arg(args, pv);
			char * field = va_arg(args, char *);
			cout << "\"" << field << "\": ";
			cout << "[" << endl;
			for (int i = 0; i < (int)f->size(); ++i)
			{
				(*f)[i]->print(0);
				if (i < (int)f->size() - 1)
					cout << "," << endl;
				else
					cout << endl;
			}
			cout << endl;
			cout << "]" << endl;
		}
		++fmt;
		if (*fmt != '\0')
			cout << "," << endl;
	}
	cout << "}" << endl;
	if ((astname != NULL) && (astname[0] != '\0'))
		cout << "}" << endl;
	va_end(args);
}

string cutout(string s1, int index, char next){//next will be ')' or ']'
    int pos = 0;
    for(int i = index; i < s1.length(); i++){
        if(s1[i] == next){
            pos = i;
            break;
        }
    }
    if(pos + 1 == s1.length())return s1.substr(0, index); //int **[3] -> int **
    string s = s1.substr(0, index) + s1.substr(pos+1, s1.length()); //int **[4][3] -> int **[3]
    return s;
}

bool compare(string s1, string s2){
    if(s2.length() > s1.length() && s2.substr(0, s1.length()) == s1)return false;
    if(s1.length() > s2.length() && s1.substr(0, s2.length()) == s2)return false;
    bool isCompatible = true;
    for(int i = 0; i < s1.length(); i++){
        if(s1[i] == '[' && s2[i] == '['){
            s1 = cutout(s1, i, ']');
            s2 = cutout(s2, i, ']');
            break;
        }
    }
    int i = 0;
    while(i != s1.length()){
        if(s1[i] == s2[i]){
            i++;
            continue;
        }
        else{
            if(s1[i] == '(' && s2[i] == '['){
                //cut out till square bracket ends for both
                s1 = cutout(s1, i, ')');
                s2 = cutout(s2, i, ']');
                // cout << "cutting once" << endl;
                // cout << s1 << " " << s2 << endl;
            } else if(s1[i] == '(' && s2[i] == '*'){
                s1 = cutout(s1, i, ')');
            } else if(s1[i] == '*' && s2[i] == '('){
                s1 = cutout(s2, i, ')');
            } else if(s1[i] == '[' && s2[i] == '['){
                s1 = cutout(s1, i, ']');
                s2 = cutout(s2, i, ']');
            } else if(s1[i] == '[' && s2[i] == '*'){
                s1 = cutout(s1, i, ']');
            } else if(s1[i] == '*' && s2[i] == '['){
                s2 = cutout(s2, i, ']');
            } else {
                return false;
            }
        }
        i++;
        if(s1.length() == i || s2.length() == i)break;
    }
    return true;
}


    
    using namespace std;
    extern SymbTab gst;
    stack<SymbTab*> lst_stack;
    int offset = 0;
    vector<Node> var_vec;
    string struct_func;
    map<std::string, abstract_astnode*> ast;
    typedef vector<statement_astnode*>* ssp;
    ssp statement_stack_pointer = new vector<statement_astnode*>();
    stack<ssp> statement_stack_pointer_stack;
    typedef vector<exp_astnode*>* esp;
    esp expression_stack_pointer;
    stack<esp> expression_stack_pointer_stack;
    typedef vector<string>* et;
    et expression_types;
    stack<et> expression_type_stack;
    string current_function_type;

#undef yylex
#define yylex IPL::Parser::scanner.yylex

}




%define api.value.type variant
%define parse.assert

%start translation_unit



%token '\n'
%token <std::string> STRUCT
%token <std::string> VOID
%token <std::string> FLOAT
%token <std::string> INT
%token <std::string> INT_CONSTANT
%token <std::string> RETURN
%token <std::string> OR_OP
%token <std::string> AND_OP
%token <std::string> EQ_OP
%token <std::string> NE_OP
%token <std::string> LE_OP
%token <std::string> GE_OP
%token <std::string> PTR_OP
%token <std::string> INC_OP
%token <std::string> FLOAT_CONSTANT
%token <std::string> STRING_LITERAL
%token <std::string> IF
%token <std::string> ELSE
%token <std::string> WHILE
%token <std::string> FOR
%token <std::string> IDENTIFIER
%token <std::string> OTHERS
%token ',' ':' '(' ')' '{' '}' ';' '[' ']' '.' '=' '<' '>' '!' '&' 
%left '+' '-'
%left '*' '/'


%nterm <Node> translation_unit struct_specifier function_definition type_specifier fun_declarator parameter_list parameter_declaration declarator_arr declarator compound_statement statement_list statement assignment_expression assignment_statement procedure_call expression logical_and_expression equality_expression relational_expression additive_expression unary_expression multiplicative_expression postfix_expression primary_expression expression_list unary_operator selection_statement iteration_statement declaration_list declaration declarator_list proccall_midrule fun_declarator_midrule compound_statement_midrule

%%
translation_unit: 
       struct_specifier
       { 
	    
       } 
       | function_definition
       {
        

       }
       | translation_unit struct_specifier
       {
        

       }
       | translation_unit function_definition
       {

       }
       ;

struct_specifier: 
        STRUCT IDENTIFIER '{' 
        {
            SymbTab* lst = new SymbTab();
            entry* ent = new entry();
            ent->scope = "global";
            ent->var_func = "struct";
            ent->name = "struct " + $2;
            if(gst.Entries.count(ent->name) != 0){
                error(@1, "struct of this name is already defined");
            }
            ent->symbol_table = lst;
            ent->type = "-";
            ent->offset = 0;
            offset = 0;
            gst.Entries.insert({ent->name, ent});
            lst_stack.push(lst);
            struct_func = "struct";
        }
        declaration_list '}' ';' 
        {
            entry* ent = gst.Entries["struct " + $2];
            ent->size = $5.size;
            lst_stack.pop();
        }
        ;

function_definition: 
        type_specifier fun_declarator 
        {
            SymbTab* lst = lst_stack.top();
            lst_stack.pop();
            entry* ent = new entry();
            ent->scope = "global";
            ent->var_func = "fun";
            ent->name = $2.name;
            if(gst.Entries.find(ent->name) != gst.Entries.end()){
                error(@1, "The function \"" + ent->name + "\" has a previous definition");
            }
            ent->size = 0;
            ent->type = $1.type;
            ent->offset = 0;
            ent->symbol_table = lst;
            gst.Entries.insert({ent->name, ent});
            lst_stack.push(lst);
            offset = 0;
            struct_func = "func";
            current_function_type = $1.type;
        }
        compound_statement
        {
            entry* ent = gst.Entries[$2.name];
            ent->symbol_table = lst_stack.top();
            lst_stack.pop();
            offset = 0;
            ast[$2.name] = $4.ast;
        }
        ;

type_specifier: 
        VOID 
        {
            $$.type = $1;
            $$.size = 4;
        }
        | INT
        {
            $$.type = $1;
            $$.size = 4;
        }
        | FLOAT
        {
            $$.type = $1;
            $$.size = 4;
        }
        | STRUCT IDENTIFIER
        {
            $$.type = $1 + " " + $2;
            $$.size = gst.Entries[$$.type]->size;
        }
        ;

fun_declarator: 
        IDENTIFIER '(' fun_declarator_midrule parameter_list ')'
        {
            // cout << "LST size in line 233 = " << lst_stack.size() << endl;
            SymbTab* lst = lst_stack.top();
            lst_stack.pop();
            $$.name = $1; 
            for (int i = var_vec.size()-1; i >= 0; i--) {
                entry *ent = new entry();
                Node* it = &var_vec[i];
                ent->name = it->name;
                ent->var_func = "var";
                ent->scope = "param";
                if(it->type == "void"){
                    error(@1, "Cannot declare the type of a parameter as  \"void\"");
                }
                ent->type = it->type;
                string temp = ent->type;
                int pos_of_star = temp.find_first_of('*');
                int pos_of_bracket = temp.find_first_of('[');
                if(pos_of_star != -1 && pos_of_bracket == -1){
                    ent->size = 4;
                }
                else{
                    ent->size = it->size;
                }
                
                ent->offset = offset;
                offset += ent->size;
                ent->symbol_table = nullptr;
                lst->Entries.insert({ent->name, ent});
            }
            var_vec.clear();
            lst_stack.push(lst);
        }
        | IDENTIFIER '(' ')'
        {
            $$.name = $1;
            offset = 0;
            SymbTab* lst = new SymbTab();
            lst_stack.push(lst);
        }
        ;

parameter_list: 
        parameter_declaration
        {
            var_vec.push_back($1);
        }
        | parameter_list ',' parameter_declaration
        {
            var_vec.push_back($3);
        }
        ;

parameter_declaration: 
        type_specifier declarator 
        {
            $$.name = $2.name;
            $$.type = $1.type + $2.type;
            $$.size = $1.size * $2.size; 
        }
        ;

declarator_arr: 
        IDENTIFIER
        {
            $$.name = $1;
            $$.type = "";
            $$.size = 1;
        }
        | declarator_arr '[' INT_CONSTANT ']' 
        {
            $$.name = $1.name;
            $$.type = $1.type + "[" + $3 + "]";
            $$.size = $1.size * stoi($3);
        }
        ;

declarator: 
        declarator_arr
        {
            $$.name = $1.name;
            $$.type = $1.type;
            $$.size = $1.size;
        }
        | '*' declarator
        {
            $$.name = $2.name;
            $$.type = "*" + $2.type;
            $$.size = $2.size;
        }
        ;

compound_statement: 
        '{' '}' 
        {
            seq_astnode* node = new seq_astnode();
            $$.ast = node;
        }
        | '{' compound_statement_midrule statement_list '}' 
        {
            seq_astnode* node = new seq_astnode();
            node->statements = *statement_stack_pointer;
            $$.ast = node;
            if(!statement_stack_pointer_stack.empty()){
                statement_stack_pointer = statement_stack_pointer_stack.top();
                statement_stack_pointer_stack.pop();
            } 
            else {
                statement_stack_pointer = new vector<statement_astnode*>();;
            }
        }
        | '{' declaration_list '}' 
        {
            seq_astnode* node = new seq_astnode();
            $$.ast = node;
        }
        | '{' declaration_list compound_statement_midrule statement_list '}'
        {
            seq_astnode* node = new seq_astnode();
            node->statements = *statement_stack_pointer;
            $$.ast = node;
            if(!statement_stack_pointer_stack.empty()){
                statement_stack_pointer = statement_stack_pointer_stack.top();
                statement_stack_pointer_stack.pop();
            } else statement_stack_pointer = new vector<statement_astnode*>();
            
        }
        ;

statement_list: 
        statement 
        {
           statement_stack_pointer->push_back((statement_astnode*) $1.ast); 
        
        }
        | statement_list statement
        {
           statement_stack_pointer->push_back((statement_astnode*) $2.ast);

        }
        ;

statement: 
        ';' 
        {
            $$.ast = new empty_astnode();
        }
        | '{' compound_statement_midrule statement_list '}' 
        {
            seq_astnode* node = new seq_astnode();
            

            node->statements = *statement_stack_pointer;
            $$.ast = node;
            
            if(!statement_stack_pointer_stack.empty()){
                statement_stack_pointer = statement_stack_pointer_stack.top();
                statement_stack_pointer_stack.pop();
            } else statement_stack_pointer = new vector<statement_astnode*>();

        }
        | selection_statement
        {
            $$.ast = $1.ast;
        }
        | iteration_statement 
        {
            $$.ast = $1.ast;
        }
        | assignment_statement 
        {
            $$.ast = $1.ast;
        }
        | procedure_call
        {
            $$.ast = $1.ast;
        }
        | RETURN expression ';'
        {
            return_astnode* return_ast = new return_astnode();

            if (current_function_type == $2.type){
                return_ast->return_statement = (exp_astnode*) $2.ast;
            }
            
            else if (current_function_type == "int" && $2.type == "float"){
                op_unary_astnode* temp = new op_unary_astnode();
                temp->op = "TO_INT";
                temp->exp = (exp_astnode*) $2.ast;
                return_ast->return_statement = (exp_astnode*) temp;
            }

            else if (current_function_type == "float" && $2.type == "int"){
                op_unary_astnode* temp = new op_unary_astnode();
                temp->op = "TO_FLOAT";
                temp->exp = (exp_astnode*) $2.ast;
                return_ast->return_statement = (exp_astnode*) temp;
            }

            else{
                error(@1, "Incompatible type \"" + $2.type + "\" returned, expected \"" + current_function_type + "\"");
            }

            $$.ast = return_ast;

        }
        ;

assignment_expression: 
        unary_expression '=' expression
        {

            // cout << $1.type << " " << $3.type << $3.iszero << endl;

            string temp = $1.type;
            int pos_of_star = temp.find_first_of('*');

            if (!$1.lvalue){
                error(@1, "Left operand of assignment should have an lvalue");
            }

            assignE_astnode* assign_expression = new assignE_astnode();
            if ($1.type == $3.type){
                assign_expression->left_exp = (exp_astnode*) $1.ast;
                assign_expression->right_exp = (exp_astnode*) $3.ast;
            }
            
            else if ($1.type == "int" && $3.type == "float"){
                op_unary_astnode* temp = new op_unary_astnode();
                temp->op = "TO_INT";
                temp->exp = (exp_astnode*) $3.ast;
                assign_expression->left_exp = (exp_astnode*) $1.ast;
                assign_expression->right_exp = (exp_astnode*) temp;
            }

            else if ($1.type == "float" && $3.type == "int"){
                op_unary_astnode* temp = new op_unary_astnode();
                temp->op = "TO_FLOAT";
                temp->exp = (exp_astnode*) $3.ast;
                assign_expression->left_exp = (exp_astnode*) $1.ast;
                assign_expression->right_exp = (exp_astnode*) temp;
            }


            else if(compare($1.type, $3.type)){
               assign_expression->left_exp = (exp_astnode*) $1.ast;
               assign_expression->right_exp = (exp_astnode*) $3.ast;
           }

           else if (pos_of_star != -1 && $3.iszero){
               assign_expression->left_exp = (exp_astnode*) $1.ast;
               assign_expression->right_exp = (exp_astnode*) $3.ast;
           }

           else{
               error(@1, "Invalid operands types for binary =, \"" + $1.type + "\" and \"" + $3.type + "\"");
           }

           


            $$.ast = assign_expression;

        }
        ;

assignment_statement: 
        assignment_expression ';' 
        {
           assignS_astnode* assignment_stat = new assignS_astnode();
           assignment_stat->left_part = ((assignE_astnode*) $1.ast)->left_exp;
           assignment_stat->right_part = ((assignE_astnode*) $1.ast)->right_exp;
           $$.ast = assignment_stat;
           
        }
        ;

procedure_call: 
        IDENTIFIER '(' ')' ';' 
        {
           proccall_astnode* proccall = new proccall_astnode();
           identifier_astnode* procname = new identifier_astnode();
           procname->identifier_name = $1;
           proccall->proc_name = procname;
           $$.ast = proccall;

        }
        | IDENTIFIER '(' proccall_midrule expression_list ')' ';' 
        {
           proccall_astnode* proccall = new proccall_astnode();
           identifier_astnode* procname = new identifier_astnode();
           procname->identifier_name = $1;
           proccall->proc_name = procname;

           if($1 == "printf" || $1 == "scanf"){
               proccall->params = *expression_stack_pointer;
           }  


           else{
               vector<pair<int, string>> lst_params;

           
                for (auto i : gst.Entries[$1]->symbol_table->Entries){
                    if (i.second->scope == "param"){
                        lst_params.push_back({-i.second->offset, i.second->type});
                    }
                }


                if(lst_params.size() < expression_types->size()){
                    error(@1, "Procedure \"" +$1+ "\"  called with too many arguments");
                }

                if(lst_params.size() > expression_types->size()){
                    error(@1, "Procedure \"" +$1+ "\"  called with too few arguments");
                }
                

                sort(lst_params.begin(), lst_params.end());
                for (int i=0; i<lst_params.size(); i++){
                    if (lst_params[i].second == (*expression_types)[i]){
                        proccall->params.push_back((*expression_stack_pointer)[i]);
                    }
                    else if (lst_params[i].second == "int" && (*expression_types)[i] == "float"){
                        op_unary_astnode* temp = new op_unary_astnode();
                        temp->op = "TO_INT";
                        temp->exp = (exp_astnode*) (*expression_stack_pointer)[i];
                        proccall->params.push_back((exp_astnode*) temp);
                    }
                    else if (lst_params[i].second == "float" && (*expression_types)[i] == "int"){
                        op_unary_astnode* temp = new op_unary_astnode();
                        temp->op = "TO_FLOAT";
                        temp->exp = (exp_astnode*) (*expression_stack_pointer)[i];
                        proccall->params.push_back((exp_astnode*) temp);
                    }
                }


                
           }

           expression_stack_pointer = expression_stack_pointer_stack.top();
                expression_stack_pointer_stack.pop();
                expression_types = expression_type_stack.top();
                expression_type_stack.pop();
                $$.ast = proccall;
           

           
        }
        ;

expression:
        logical_and_expression
        {
            $$.ast = $1.ast;
            $$.type = $1.type;
            $$.iszero = $1.iszero;
            $$.lvalue = $1.lvalue;
        }
        | expression OR_OP logical_and_expression
        {
           op_binary_astnode* exp = new op_binary_astnode();
           exp->left_exp = (exp_astnode*) $1.ast;
           exp->right_exp = (exp_astnode*) $3.ast;
           exp->op = "OR_OP";
           $$.ast = exp;
           $$.type = "int";
        }
        ;

logical_and_expression: 
        equality_expression 
        {
            $$.ast = $1.ast;
            $$.type = $1.type;
            $$.iszero = $1.iszero;
            $$.lvalue = $1.lvalue;
        }
        | logical_and_expression AND_OP equality_expression
        {
           op_binary_astnode* exp = new op_binary_astnode();
           exp->left_exp = (exp_astnode*) $1.ast;
           exp->right_exp = (exp_astnode*) $3.ast;
           exp->op = "AND_OP";
           $$.ast = exp;
           $$.type = "int";
        }
        ;

equality_expression: 
        relational_expression
        {
           $$.ast = $1.ast;
           $$.type = $1.type;
           $$.iszero = $1.iszero;
           $$.lvalue = $1.lvalue;

        }
        | equality_expression EQ_OP relational_expression
        {
           op_binary_astnode* exp = new op_binary_astnode();
           

           if ($1.type == "int" && $3.type == "int"){
               exp->left_exp = (exp_astnode*) $1.ast;
               exp->right_exp = (exp_astnode*) $3.ast;
               exp->op = "EQ_OP_INT";
               $$.type = "int";
           }
           
           else if ($1.type == "int" && $3.type == "float"){
               op_unary_astnode* temp = new op_unary_astnode();
               temp->op = "TO_FLOAT";
               temp->exp = (exp_astnode*) $1.ast;
               exp->left_exp = (exp_astnode*) temp;
               exp->right_exp = (exp_astnode*) $3.ast;
               exp->op = "EQ_OP_FLOAT";
               $$.type = "float";
           }

           else if ($1.type == "float" && $3.type == "int"){
               op_unary_astnode* temp = new op_unary_astnode();
               temp->op = "TO_FLOAT";
               temp->exp = (exp_astnode*) $3.ast;
               exp->left_exp = (exp_astnode*) $1.ast;
               exp->right_exp = (exp_astnode*) temp;
               exp->op = "EQ_OP_FLOAT";
               $$.type = "float";
           }

           else if ($1.type == "float" && $3.type == "float"){
               exp->left_exp = (exp_astnode*) $1.ast;
               exp->right_exp = (exp_astnode*) $3.ast;
               exp->op = "EQ_OP_FLOAT";
               $$.type = "float";
           }

           else if(compare($1.type, $3.type)){
               exp->left_exp = (exp_astnode*) $1.ast;
               exp->right_exp = (exp_astnode*) $3.ast;
               string temp = $1.type;
               if(temp.substr(0, 3) == "int"){
                   exp->op = "EQ_OP_INT";
                   $$.type = "int";
               }
               else{
                   exp->op = "EQ_OP_FLOAT";
                   $$.type = "float";
               }
           }


           else{
               error(@1, "Invalid operands types for binary ==, \"" + $1.type + "\" and \"" + $3.type + "\"");
           }

           
           $$.ast = exp;
        }
        |  equality_expression NE_OP relational_expression
        {
           op_binary_astnode* exp = new op_binary_astnode();
           

           if ($1.type == "int" && $3.type == "int"){
               exp->left_exp = (exp_astnode*) $1.ast;
               exp->right_exp = (exp_astnode*) $3.ast;
               exp->op = "NE_OP_INT";
               $$.type = "int";
           }
           
           else if ($1.type == "int" && $3.type == "float"){
               op_unary_astnode* temp = new op_unary_astnode();
               temp->op = "TO_FLOAT";
               temp->exp = (exp_astnode*) $1.ast;
               exp->left_exp = (exp_astnode*) temp;
               exp->right_exp = (exp_astnode*) $3.ast;
               exp->op = "NE_OP_FLOAT";
               $$.type = "float";
           }

           else if ($1.type == "float" && $3.type == "int"){
               op_unary_astnode* temp = new op_unary_astnode();
               temp->op = "TO_FLOAT";
               temp->exp = (exp_astnode*) $3.ast;
               exp->left_exp = (exp_astnode*) $1.ast;
               exp->right_exp = (exp_astnode*) temp;
               exp->op = "NE_OP_FLOAT";
               $$.type = "float";
           }

           else if ($1.type == "float" && $3.type == "float"){
               exp->left_exp = (exp_astnode*) $1.ast;
               exp->right_exp = (exp_astnode*) $3.ast;
               exp->op = "NE_OP_FLOAT";
               $$.type = "float";
           }

            else if(compare($1.type, $3.type)){
               exp->left_exp = (exp_astnode*) $1.ast;
               exp->right_exp = (exp_astnode*) $3.ast;
               string temp = $1.type;
               if(temp.substr(0, 3) == "int"){
                   exp->op = "NE_OP_INT";
                   $$.type = "int";
               }
               else{
                   exp->op = "NE_OP_FLOAT";
                   $$.type = "float";
               }
           }


           else{
               error(@1, "Invalid operands types for binary !=, \"" + $1.type + "\" and \"" + $3.type + "\"");
           }

           
           $$.ast = exp;
        }
        ;

relational_expression: 
        additive_expression
        {
           $$.ast = $1.ast;
           $$.type = $1.type;
           $$.iszero = $1.iszero;
           $$.lvalue = $1.lvalue;
        }
        | relational_expression '<' additive_expression
        {
           op_binary_astnode* exp = new op_binary_astnode();
           

           if ($1.type == "int" && $3.type == "int"){
               exp->left_exp = (exp_astnode*) $1.ast;
               exp->right_exp = (exp_astnode*) $3.ast;
               exp->op = "LT_OP_INT";
               $$.type = "int";
           }
           
           else if ($1.type == "int" && $3.type == "float"){
               op_unary_astnode* temp = new op_unary_astnode();
               temp->op = "TO_FLOAT";
               temp->exp = (exp_astnode*) $1.ast;
               exp->left_exp = (exp_astnode*) temp;
               exp->right_exp = (exp_astnode*) $3.ast;
               exp->op = "LT_OP_FLOAT";
               $$.type = "float";
           }

           else if ($1.type == "float" && $3.type == "int"){
               op_unary_astnode* temp = new op_unary_astnode();
               temp->op = "TO_FLOAT";
               temp->exp = (exp_astnode*) $3.ast;
               exp->left_exp = (exp_astnode*) $1.ast;
               exp->right_exp = (exp_astnode*) temp;
               exp->op = "LT_OP_FLOAT";
               $$.type = "float";
           }

           else if ($1.type == "float" && $3.type == "float"){
               exp->left_exp = (exp_astnode*) $1.ast;
               exp->right_exp = (exp_astnode*) $3.ast;
               exp->op = "LT_OP_FLOAT";
               $$.type = "float";
           }
           
           else if(compare($1.type, $3.type)){
               exp->left_exp = (exp_astnode*) $1.ast;
               exp->right_exp = (exp_astnode*) $3.ast;
               string temp = $1.type;
               if(temp.substr(0, 3) == "int"){
                   exp->op = "LT_OP_INT";
                   $$.type = "int";
               }
               else{
                   exp->op = "LT_OP_FLOAT";
                   $$.type = "float";
               }
           }

           else{
               error(@1, "Invalid operands types for binary <, \"" + $1.type + "\" and \"" + $3.type + "\"");
           }
           

           
           $$.ast = exp;
        }
        | relational_expression '>' additive_expression
        {
           op_binary_astnode* exp = new op_binary_astnode();
           

           if ($1.type == "int" && $3.type == "int"){
               exp->left_exp = (exp_astnode*) $1.ast;
               exp->right_exp = (exp_astnode*) $3.ast;
               exp->op = "GT_OP_INT";
               $$.type = "int";
           }
           
           else if ($1.type == "int" && $3.type == "float"){
               op_unary_astnode* temp = new op_unary_astnode();
               temp->op = "TO_FLOAT";
               temp->exp = (exp_astnode*) $1.ast;
               exp->left_exp = (exp_astnode*) temp;
               exp->right_exp = (exp_astnode*) $3.ast;
               exp->op = "GT_OP_FLOAT";
               $$.type = "float";
           }

           else if ($1.type == "float" && $3.type == "int"){
               op_unary_astnode* temp = new op_unary_astnode();
               temp->op = "TO_FLOAT";
               temp->exp = (exp_astnode*) $3.ast;
               exp->left_exp = (exp_astnode*) $1.ast;
               exp->right_exp = (exp_astnode*) temp;
               exp->op = "GT_OP_FLOAT";
               $$.type = "float";
           }

           else if ($1.type == "float" && $3.type == "float"){
               exp->left_exp = (exp_astnode*) $1.ast;
               exp->right_exp = (exp_astnode*) $3.ast;
               exp->op = "GT_OP_FLOAT";
               $$.type = "float";
           }

           else if(compare($1.type, $3.type)){
               exp->left_exp = (exp_astnode*) $1.ast;
               exp->right_exp = (exp_astnode*) $3.ast;
               string temp = $1.type;
               if(temp.substr(0, 3) == "int"){
                   exp->op = "GT_OP_INT";
                   $$.type = "int";
               }
               else{
                   exp->op = "GT_OP_FLOAT";
                   $$.type = "float";
               }
           }

           else{
               error(@1, "Invalid operands types for binary >, \"" + $1.type + "\" and \"" + $3.type + "\"");
           }

           
           $$.ast = exp;
        }
        | relational_expression LE_OP additive_expression
        {
           op_binary_astnode* exp = new op_binary_astnode();
           

           if ($1.type == "int" && $3.type == "int"){
               exp->left_exp = (exp_astnode*) $1.ast;
               exp->right_exp = (exp_astnode*) $3.ast;
               exp->op = "LE_OP_INT";
               $$.type = "int";
           }
           
           else if ($1.type == "int" && $3.type == "float"){
               op_unary_astnode* temp = new op_unary_astnode();
               temp->op = "TO_FLOAT";
               temp->exp = (exp_astnode*) $1.ast;
               exp->left_exp = (exp_astnode*) temp;
               exp->right_exp = (exp_astnode*) $3.ast;
               exp->op = "LE_OP_FLOAT";
               $$.type = "float";
           }

           else if ($1.type == "float" && $3.type == "int"){
               op_unary_astnode* temp = new op_unary_astnode();
               temp->op = "TO_FLOAT";
               temp->exp = (exp_astnode*) $3.ast;
               exp->left_exp = (exp_astnode*) $1.ast;
               exp->right_exp = (exp_astnode*) temp;
               exp->op = "LE_OP_FLOAT";
               $$.type = "float";
           }

           else if ($1.type == "float" && $3.type == "float"){
               exp->left_exp = (exp_astnode*) $1.ast;
               exp->right_exp = (exp_astnode*) $3.ast;
               exp->op = "LE_OP_FLOAT";
               $$.type = "float";
           }

           else if(compare($1.type, $3.type)){
               exp->left_exp = (exp_astnode*) $1.ast;
               exp->right_exp = (exp_astnode*) $3.ast;
               string temp = $1.type;
               if(temp.substr(0, 3) == "int"){
                   exp->op = "LE_OP_INT";
                   $$.type = "int";
               }
               else{
                   exp->op = "LE_OP_FLOAT";
                   $$.type = "float";
               }
           }

           else{
               error(@1, "Invalid operands types for binary <=, \"" + $1.type + "\" and \"" + $3.type + "\"");
           }

           
           $$.ast = exp;
        }
        | relational_expression GE_OP additive_expression
        {
           op_binary_astnode* exp = new op_binary_astnode();
           

           if ($1.type == "int" && $3.type == "int"){
               exp->left_exp = (exp_astnode*) $1.ast;
               exp->right_exp = (exp_astnode*) $3.ast;
               exp->op = "GE_OP_INT";
               $$.type = "int";
           }
           
           else if ($1.type == "int" && $3.type == "float"){
               op_unary_astnode* temp = new op_unary_astnode();
               temp->op = "TO_FLOAT";
               temp->exp = (exp_astnode*) $1.ast;
               exp->left_exp = (exp_astnode*) temp;
               exp->right_exp = (exp_astnode*) $3.ast;
               exp->op = "GE_OP_FLOAT";
               $$.type = "float";
           }

           else if ($1.type == "float" && $3.type == "int"){
               op_unary_astnode* temp = new op_unary_astnode();
               temp->op = "TO_FLOAT";
               temp->exp = (exp_astnode*) $3.ast;
               exp->left_exp = (exp_astnode*) $1.ast;
               exp->right_exp = (exp_astnode*) temp;
               exp->op = "GE_OP_FLOAT";
               $$.type = "float";
           }

           else if ($1.type == "float" && $3.type == "float"){
               exp->left_exp = (exp_astnode*) $1.ast;
               exp->right_exp = (exp_astnode*) $3.ast;
               exp->op = "GE_OP_FLOAT";
               $$.type = "float";
           }

           else if(compare($1.type, $3.type)){
               exp->left_exp = (exp_astnode*) $1.ast;
               exp->right_exp = (exp_astnode*) $3.ast;
               string temp = $1.type;
               if(temp.substr(0, 3) == "int"){
                   exp->op = "GE_OP_INT";
                   $$.type = "int";
               }
               else{
                   exp->op = "GE_OP_FLOAT";
                   $$.type = "float";
               }
           }

           else{
               error(@1, "Invalid operands types for binary >=, \"" + $1.type + "\" and \"" + $3.type + "\"");
           }

           
           $$.ast = exp;
        }
        ;

additive_expression:
        multiplicative_expression
        {
          $$.ast = $1.ast;
          $$.type = $1.type;
          $$.iszero = $1.iszero;
          $$.lvalue = $1.lvalue;
        }
        | additive_expression '+' multiplicative_expression
        {
           op_binary_astnode* exp = new op_binary_astnode();
           string temp = $1.type;
           int pos_of_star = temp.find_first_of('*');
           int pos_of_bracket = temp.find_first_of('[');

           if ($1.type == "int" && $3.type == "int"){
               exp->left_exp = (exp_astnode*) $1.ast;
               exp->right_exp = (exp_astnode*) $3.ast;
               exp->op = "PLUS_INT";
               $$.type = "int";
           }
           
           else if ($1.type == "int" && $3.type == "float"){
               op_unary_astnode* temp = new op_unary_astnode();
               temp->op = "TO_FLOAT";
               temp->exp = (exp_astnode*) $1.ast;
               exp->left_exp = (exp_astnode*) temp;
               exp->right_exp = (exp_astnode*) $3.ast;
               exp->op = "PLUS_FLOAT";
               $$.type = "float";
           }

           else if ($1.type == "float" && $3.type == "int"){
               op_unary_astnode* temp = new op_unary_astnode();
               temp->op = "TO_FLOAT";
               temp->exp = (exp_astnode*) $3.ast;
               exp->left_exp = (exp_astnode*) $1.ast;
               exp->right_exp = (exp_astnode*) temp;
               exp->op = "PLUS_FLOAT";
               $$.type = "float";
           }

           else if ($1.type == "float" && $3.type == "float"){
               exp->left_exp = (exp_astnode*) $1.ast;
               exp->right_exp = (exp_astnode*) $3.ast;
               exp->op = "PLUS_FLOAT";
               $$.type = "float";
           }

            else if ((pos_of_star != -1 || pos_of_bracket != -1) && $3.type == "int"){
                exp->left_exp = (exp_astnode*) $1.ast;
                exp->right_exp = (exp_astnode*) $3.ast;
                exp->op = "PLUS_INT";
                $$.type = $1.type;
            }

            else{
                error(@1, "Invalid operand types for binary + , \"" + $1.type + "\" and \"" + $3.type + "\"");
            }
           
           

           
           $$.ast = exp;
        }
        | additive_expression '-' multiplicative_expression
        {
           op_binary_astnode* exp = new op_binary_astnode();
           string temp = $1.type;
           int pos_of_star = temp.find_first_of('*');
           int pos_of_bracket = temp.find_first_of('[');
           

           if ($1.type == "int" && $3.type == "int"){
               exp->left_exp = (exp_astnode*) $1.ast;
               exp->right_exp = (exp_astnode*) $3.ast;
               exp->op = "MINUS_INT";
               $$.type = "int";
           }
           
           else if ($1.type == "int" && $3.type == "float"){
               op_unary_astnode* temp = new op_unary_astnode();
               temp->op = "TO_FLOAT";
               temp->exp = (exp_astnode*) $1.ast;
               exp->left_exp = (exp_astnode*) temp;
               exp->right_exp = (exp_astnode*) $3.ast;
               exp->op = "MINUS_FLOAT";
               $$.type = "float";
           }

           else if ($1.type == "float" && $3.type == "int"){
               op_unary_astnode* temp = new op_unary_astnode();
               temp->op = "TO_FLOAT";
               temp->exp = (exp_astnode*) $3.ast;
               exp->left_exp = (exp_astnode*) $1.ast;
               exp->right_exp = (exp_astnode*) temp;
               exp->op = "MINUS_FLOAT";
               $$.type = "float";
           }

           else if ($1.type == "float" && $3.type == "float"){
               exp->left_exp = (exp_astnode*) $1.ast;
               exp->right_exp = (exp_astnode*) $3.ast;
               exp->op = "MINUS_FLOAT";
               $$.type = "float";
           }

           else if(compare($1.type, $3.type)){
               exp->left_exp = (exp_astnode*) $1.ast;
               exp->right_exp = (exp_astnode*) $3.ast;
               string temp = $1.type;
               if(temp.substr(0, 3) == "int"){
                   exp->op = "MINUS_INT";
                   $$.type = "int";
               }
               else{
                   exp->op = "MINUS_FLOAT";
                   $$.type = "float";
               }
           }


            
            

           else if ((pos_of_star != -1 || pos_of_bracket != -1) && $3.type == "int"){
                exp->left_exp = (exp_astnode*) $1.ast;
                exp->right_exp = (exp_astnode*) $3.ast;
                exp->op = "MINUS_INT";
                $$.type = $1.type;
            }

            else{
                error(@1, "Invalid operands types for binary -, \"" + $1.type + "\" and \"" + $3.type + "\"");
            }

           
           $$.ast = exp;
        }
        ;

unary_expression:
        postfix_expression
        {
            $$.ast = $1.ast;
            $$.type = $1.type;
            $$.iszero = $1.iszero;
            $$.lvalue = $1.lvalue;

        }
        | unary_operator unary_expression
        {
            op_unary_astnode* unary_exp = new op_unary_astnode();
            unary_exp->op = $1.text;
            unary_exp->exp = (exp_astnode*) $2.ast;
            $$.ast = unary_exp;

            if ($1.text == "UMINUS"){

                if ($2.type == "int" || $2.type == "float"){
                    $$.type = $2.type;
                    $$.lvalue = false;
                }
                else{
                    error(@1, "Operand of unary - should be an int or float");
                }
                
            }

            else if ($1.text == "NOT"){
                
                string temp = $2.type;
                int pos_of_star = temp.find_first_of('*');
                int pos_of_bracket = temp.find_first_of('[');
                if(($2.type == "int" || $2.type == "float") || (pos_of_star != -1 || pos_of_bracket != -1)){
                    $$.type = "int";
                    $$.lvalue = false;
                }
                else{
                    error(@1, "Operand of unary ! should be int, float, or a pointer");
                }
                
            }

            else if ($1.text == "ADDRESS"){
                string temp = $2.type;
                int pos_of_open_bracket = temp.find_first_of("[");
                int pos_of_star = temp.find_first_of("(*)");
                int pos_of_round_bracket = temp.find_first_of('(');
                $$.lvalue = false;
                if(pos_of_open_bracket == -1 && pos_of_star == -1){
                    $$.type = temp + "*";
                }
                else if (pos_of_open_bracket != -1 && pos_of_star == -1){
                    $$.type = temp.substr(0, pos_of_open_bracket) + "(*)" + temp.substr(pos_of_open_bracket, temp.length());
                }
                else if (pos_of_star != -1 && pos_of_round_bracket == -1){
                    if(pos_of_open_bracket == -1){
                        $$.type = temp + "(*)";
                    }
                    else{
                        $$.type = temp.substr(0, pos_of_open_bracket) + "(*)" + temp.substr(pos_of_open_bracket, temp.length());
                    }
                }
                else{
                    error(@1, "Operand of unary & should be an lvalue");
                }
            }

            else if ($1.text == "DEREF"){
                string temp = $2.type;
                int pos_of_round_bracket_open = temp.find_first_of("(");
                int pos_of_round_brackt_close = temp.find_first_of(")");
                int pos_of_square_bracket_open = temp.find_first_of("[");
                int pos_of_square_bracket_close = temp.find_first_of("]");
                int pos_of_star = temp.find_first_of("*");
                if(pos_of_round_bracket_open != -1){
                    $$.type = temp.substr(0, pos_of_round_bracket_open) + temp.substr(pos_of_round_brackt_close+1, temp.length());
                }
                else if (pos_of_square_bracket_open != -1){
                    $$.type = temp.substr(0, pos_of_square_bracket_open) + temp.substr(pos_of_square_bracket_close+1, temp.length());
                }
                else if (pos_of_star != -1){
                    $$.type = temp.substr(0, temp.length()-1);
                }
                else{
                    error(@1, "Operand of unary * should be a pointer to a complete type");
                }
            }

        }
        ;

multiplicative_expression:
        unary_expression
        {
            $$.ast = $1.ast;
            $$.type = $1.type;
            $$.iszero = $1.iszero;
            $$.lvalue = $1.lvalue;
        }
        | multiplicative_expression '*' unary_expression
        {
           op_binary_astnode* exp = new op_binary_astnode();
           

           if ($1.type == "int" && $3.type == "int"){
               exp->left_exp = (exp_astnode*) $1.ast;
               exp->right_exp = (exp_astnode*) $3.ast;
               exp->op = "MULT_INT";
               $$.type = "int";
           }
           
           else if ($1.type == "int" && $3.type == "float"){
               op_unary_astnode* temp = new op_unary_astnode();
               temp->op = "TO_FLOAT";
               temp->exp = (exp_astnode*) $1.ast;
               exp->left_exp = (exp_astnode*) temp;
               exp->right_exp = (exp_astnode*) $3.ast;
               exp->op = "MULT_FLOAT";
               $$.type = "float";
           }

           else if ($1.type == "float" && $3.type == "int"){
               op_unary_astnode* temp = new op_unary_astnode();
               temp->op = "TO_FLOAT";
               temp->exp = (exp_astnode*) $3.ast;
               exp->left_exp = (exp_astnode*) $1.ast;
               exp->right_exp = (exp_astnode*) temp;
               exp->op = "MULT_FLOAT";
               $$.type = "float";
           }

           else if ($1.type == "float" && $3.type == "float"){
               exp->left_exp = (exp_astnode*) $1.ast;
               exp->right_exp = (exp_astnode*) $3.ast;
               exp->op = "MULT_FLOAT";
               $$.type = "float";
           }

           
           $$.ast = exp;
        }
        | multiplicative_expression '/' unary_expression
        {
           op_binary_astnode* exp = new op_binary_astnode();
           

           if ($1.type == "int" && $3.type == "int"){
               exp->left_exp = (exp_astnode*) $1.ast;
               exp->right_exp = (exp_astnode*) $3.ast;
               exp->op = "DIV_INT";
               $$.type = "int";
           }
           
           else if ($1.type == "int" && $3.type == "float"){
               op_unary_astnode* temp = new op_unary_astnode();
               temp->op = "TO_FLOAT";
               temp->exp = (exp_astnode*) $1.ast;
               exp->left_exp = (exp_astnode*) temp;
               exp->right_exp = (exp_astnode*) $3.ast;
               exp->op = "DIV_FLOAT";
               $$.type = "float";
           }

           else if ($1.type == "float" && $3.type == "int"){
               op_unary_astnode* temp = new op_unary_astnode();
               temp->op = "TO_FLOAT";
               temp->exp = (exp_astnode*) $3.ast;
               exp->left_exp = (exp_astnode*) $1.ast;
               exp->right_exp = (exp_astnode*) temp;
               exp->op = "DIV_FLOAT";
               $$.type = "float";
           }

           else if ($1.type == "float" && $3.type == "float"){
               exp->left_exp = (exp_astnode*) $1.ast;
               exp->right_exp = (exp_astnode*) $3.ast;
               exp->op = "DIV_FLOAT";
               $$.type = "float";
           }

           
           $$.ast = exp;
        } 
        ;

postfix_expression:
        primary_expression
        {
           $$.ast = $1.ast;
           $$.type = $1.type;
           $$.iszero = $1.iszero;
           $$.lvalue = $1.lvalue;
        }
        | postfix_expression '[' expression ']' 
        {
            arrayref_astnode* array_exp = new arrayref_astnode();
            array_exp->array_name = (exp_astnode*) $1.ast;
            array_exp->array_index = (exp_astnode*) $3.ast;
            $$.ast = array_exp;
            string temp = $1.type;
            int pos_of_round_bracket_open = temp.find_first_of('(');
            int pos_of_round_brackt_close = temp.find_first_of(')');
            int pos_of_open_bracket = temp.find_first_of('[');
            int pos_of_close_bracket = temp.find_first_of(']');
            if (pos_of_round_bracket_open != -1){
                $$.type = temp.substr(0, pos_of_round_bracket_open) + temp.substr(pos_of_round_brackt_close+1, temp.length());
            }
            else if (pos_of_open_bracket != -1){
                temp.erase(pos_of_open_bracket, pos_of_close_bracket-pos_of_open_bracket+1);
            }
            else{
                error(@1, "Cannot put the left expression in square brackets");
            }
            
            $$.type = temp;
        }
        | IDENTIFIER '(' ')'
        {
            if (gst.Entries.find($1) != gst.Entries.end()){
                funccall_astnode* function_call = new funccall_astnode();
                identifier_astnode* function_name = new identifier_astnode();
                function_name->identifier_name = $1;
                function_call->func_name = function_name;
                $$.ast = function_call;
                $$.type = gst.Entries[$1]->type;
                $$.lvalue = false;

            }
            else{
                error(@1, "Function \"" + $1 + "\"  not declared");
            }
            
        }
        | IDENTIFIER '(' proccall_midrule expression_list ')' 
        {

            if (gst.Entries.find($1) == gst.Entries.end()){
                error(@1, "Function \"" + $1 + "\"  not declared");
            }
           funccall_astnode* funccall = new funccall_astnode();
           identifier_astnode* funcname = new identifier_astnode();
           funcname->identifier_name = $1;
           funccall->func_name = funcname;
           $$.lvalue = false;
           
           if($1 == "printf" || $1 == "scanf"){
               funccall->params = *expression_stack_pointer;
           }
           
           else{

            
               
                vector<pair<int, string>> lst_params;
                for (auto i : gst.Entries[$1]->symbol_table->Entries){
                    if (i.second->scope == "param"){
                        lst_params.push_back({-i.second->offset, i.second->type});
                    }
                }
                sort(lst_params.begin(), lst_params.end());

                
                for (int i=0; i<lst_params.size(); i++){
                    if (lst_params[i].second == (*expression_types)[i]){
                        funccall->params.push_back((*expression_stack_pointer)[i]);
                    }
                    else if (lst_params[i].second == "int" && (*expression_types)[i] == "float"){
                        op_unary_astnode* temp = new op_unary_astnode();
                        temp->op = "TO_INT";
                        temp->exp = (exp_astnode*) (*expression_stack_pointer)[i];
                        funccall->params.push_back((exp_astnode*) temp);
                    }
                    else if (lst_params[i].second == "float" && (*expression_types)[i] == "int"){
                        op_unary_astnode* temp = new op_unary_astnode();
                        temp->op = "TO_FLOAT";
                        temp->exp = (exp_astnode*) (*expression_stack_pointer)[i];
                        funccall->params.push_back((exp_astnode*) temp);
                    }
                    else {
                        error(@1, "Expected \"" + lst_params[i].second + "\" but argument is of type \"" + (*expression_types)[i] + "\"");
                    }
                }
                


                
           }
           expression_stack_pointer = expression_stack_pointer_stack.top();
                expression_stack_pointer_stack.pop();
                if(expression_type_stack.size() == 0){
                    expression_types = new vector<string>();
                }
                else{
                    expression_types = expression_type_stack.top();
                    expression_type_stack.pop();
                }

                
                $$.ast = funccall;
                $$.type = gst.Entries[$1]->type;
           
    
           
        }
        | postfix_expression '.' IDENTIFIER
        {
            member_astnode* member_expression = new member_astnode();
            member_expression->struct_name = (exp_astnode*) $1.ast;
            identifier_astnode* identifier_of_struct = new identifier_astnode();
            identifier_of_struct->identifier_name = $3;
            member_expression->struct_field = identifier_of_struct;
            $$.ast = member_expression;
            $$.type = gst.Entries[$1.type]->symbol_table->Entries[$3]->type;
        }
        |  postfix_expression PTR_OP IDENTIFIER
        {
            arrow_astnode* arrow_expression = new arrow_astnode();
            arrow_expression->pointer_name = (exp_astnode*) $1.ast;
            identifier_astnode* identifier_of_pointer = new identifier_astnode();
            identifier_of_pointer->identifier_name = $3;
            arrow_expression->pointer_field = identifier_of_pointer;
            $$.ast = arrow_expression;
            string temp = $1.type;
            int pos_of_open_bracket = temp.find_first_of('[');
            int pos_of_close_bracket = temp.find_first_of(']');
            int pos_of_star = temp.find_first_of('*');
            if(pos_of_open_bracket == -1){
                temp.erase(temp.length()-1);
            }
            else if(pos_of_star == -1){
                temp = temp.substr(0, pos_of_open_bracket);
            }
            $$.type = gst.Entries[temp]->symbol_table->Entries[$3]->type;
        }
        | postfix_expression INC_OP
        {
           op_unary_astnode* inc_op_expression = new op_unary_astnode();
           inc_op_expression->op = "PP";
           inc_op_expression->exp = (exp_astnode*) $1.ast;
           $$.ast = inc_op_expression;
           string temp = $1.type;
           int pos_of_star = temp.find_first_of('*');
           $$.lvalue = false;
           if($1.type != "int" && $1.type != "float" && pos_of_star == -1){
               error(@1, "The operand of ++ should either be int, float, or a pointer");
           }
           else{
               $$.type = $1.type;
           } 
        }
        ;

primary_expression: 
        IDENTIFIER
        {
            identifier_astnode* identifier_exp = new identifier_astnode();
            identifier_exp->identifier_name = $1;
            $$.ast = identifier_exp;
            SymbTab* lst = lst_stack.top();
            if(lst->Entries.find($1) != lst->Entries.end()){
                $$.type = lst->Entries[$1]->type;
            }
            else{
                error(@1, "Variable \"" + $1 + "\" not declared");
            }
            
        }
        | INT_CONSTANT
        {
           intconst_astnode* intconst = new intconst_astnode();
           intconst->value = $1;
           $$.ast = intconst;
           $$.type = "int";
           $$.lvalue = false;
           if($1 == "0"){
               $$.iszero = true;
           }
        }
        | FLOAT_CONSTANT
        {
           floatconst_astnode* floatconst = new floatconst_astnode();
           floatconst->value = $1;
           $$.ast = floatconst;
           $$.type = "float";
           $$.lvalue = false;
           if ($1 == "0.0"){
               $$.iszero = true;
           }
        }
        | STRING_LITERAL
        {
           stringconst_astnode* stringconst = new stringconst_astnode();
           stringconst->value = $1;
           $$.ast = stringconst;
           $$.type = "string";
           $$.lvalue = false;
        }
        | '(' expression ')' 
        {
           $$.ast = $2.ast;
           $$.type = $2.type;
        }
        ;

expression_list:
        expression
        {
           expression_stack_pointer->push_back((exp_astnode*) $1.ast);
           expression_types->push_back($1.type);
           $$.ast = $1.ast;
        }
        | expression_list ',' expression
        {
           expression_stack_pointer->push_back((exp_astnode*) $3.ast);
           expression_types->push_back($3.type);
           $$.ast = $1.ast;
        }
        ;

unary_operator:
        '-' 
        {
           $$.text = "UMINUS";
        }
        | '!' 
        {
           $$.text = "NOT";
        }
        | '&' 
        {
           $$.text = "ADDRESS";
        }
        | '*' 
        {
           $$.text = "DEREF";
        }
        ;

selection_statement:
        IF '(' expression ')' statement ELSE statement
        {
            
            if_astnode* if_statement = new if_astnode();
            if_statement->condition = (exp_astnode*) $3.ast;
            if_statement->then_statement = (statement_astnode*) $5.ast;
            if_statement->else_statement = (statement_astnode*) $7.ast;
            $$.ast = if_statement;
            
        }
        ;

iteration_statement:
        WHILE '(' expression ')' statement
        {
            while_astnode* while_statement = new while_astnode();
            while_statement->condition = (exp_astnode*) $3.ast;
            while_statement->then_statement = (statement_astnode*) $5.ast;
            $$.ast = while_statement;
        }
        | FOR '(' assignment_expression ';' expression ';' assignment_expression ')' statement
        {
            for_astnode* for_statement = new for_astnode();
            for_statement->init_condition = (exp_astnode*) $3.ast;
            for_statement->guard_condition = (exp_astnode*) $5.ast;
            for_statement->step_condition = (exp_astnode*) $7.ast;
            for_statement->then_statement = (statement_astnode*) $9.ast;
            $$.ast = for_statement;
        }
        ;

declaration_list:
        declaration
        {
            $$.size = $1.size;
        }
        | declaration_list declaration
        {
            $$.size = $1.size + $2.size;
        }
        ;

declaration:
        type_specifier declarator_list ';' 
        {
            string temp = $1.type;
            int pos_of_void = temp.find("void");
            if(pos_of_void != -1){
                error(@1, "Cannot declare variable of type \"" + temp + "\"");
            }
            SymbTab* lst = lst_stack.top();
            lst_stack.pop();
            int size = 0;
            for (int i = 0; i < var_vec.size(); i++) {
                entry *ent = new entry();
                Node* it = &var_vec[i];
                ent->name = it->name;
                if(lst->Entries.find(ent->name) != lst->Entries.end()){
                    error(@1, "\"" + ent->name + "\" has a previous declaration");
                }
                ent->var_func = "var";
                ent->scope = "local";
                ent->type = $1.type + it->type;

                int pos_of_star = ent->type.find_first_of('*');
                int pos_of_bracket = ent->type.find_first_of('[');

                if(pos_of_star != -1 && pos_of_bracket == -1){
                    ent->size = 4;
                }
                else{
                    ent->size = $1.size * it->size;
                }
                size += ent->size;
                if (struct_func == "func"){
                    offset -= ent->size;
                    ent->offset = offset;
                }
                else {
                    ent->offset = offset;
                    offset += ent->size;
                }
                ent->symbol_table = nullptr;
                lst->Entries.insert({ent->name, ent});
            }
            var_vec.clear();
            lst_stack.push(lst);
            $$.size = size;
        }
        ;

declarator_list:
        declarator
        {
            var_vec.push_back($1);
        }
        | declarator_list ',' declarator
        {
            var_vec.push_back($3);
        }
        ;


fun_declarator_midrule:
        %empty
        {
            SymbTab* lst = new SymbTab();
            lst_stack.push(lst);
            offset = 12;
        }

compound_statement_midrule:
        %empty
        {
            statement_stack_pointer_stack.push(statement_stack_pointer);
            statement_stack_pointer = new vector<statement_astnode*>();
        }

proccall_midrule:
        %empty
        {
            expression_stack_pointer_stack.push(expression_stack_pointer);
            expression_type_stack.push(expression_types);

            expression_stack_pointer = new vector<exp_astnode*>();
            expression_types = new vector<string>();
        }





%%
void IPL::Parser::error( const location_type &l, const std::string &err_message )
{
   std::cout << "Error at line " << l.begin.line << ": " << err_message << endl;
   exit(1);
}


