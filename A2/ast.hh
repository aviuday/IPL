#include <iostream> 
#include <vector>
#include <map> 
#include <string> 
#include <stack> 
#include <algorithm> 
#include <stdarg.h>
#include <utility>

using namespace std;

extern void printAst(const char *astname, const char *fmt, ...);

enum typeAst { 
    seq_astnode_type, 
    empty_astnode_type, 
    return_astnode_type, 
    assignS_astnode_type, 
	assignE_astnode_type,
    if_astnode_type, 
    while_astnode_type, 
    for_astnode_type, 
    proccall_astnode_type, 
    identifier_astnode_type, 
    array_astnode_type, 
    member_astnode_type, 
    arrow_astnode_type, 
    unary_op_astnode_type, 
    binary_op_astnode_type, 
    function_call_astnode_type, 
    int_constant_astnode_type, 
    string_constant_astnode_type, 
    float_constant_astnode_type, 
};




class abstract_astnode { 
    public: 
    virtual void print(int blanks) = 0;
    enum typeAst astnode_type;
};


class statement_astnode : public abstract_astnode{ 


	public:

	void print(int blanks){ 

	}

};

class exp_astnode : public abstract_astnode{ 

	public:	

	void print(int blanks){ 
		
	}

};

class ref_astnode : public exp_astnode{ 

	public:

	void print(int blanks){ 
		
	}
};

class empty_astnode : public statement_astnode{ 

	public: 

	empty_astnode(){
		astnode_type = empty_astnode_type;
	}

	void print(int blanks){ 
		cout << "\"empty\"" << endl;
	}
};

class seq_astnode : public statement_astnode{ 

    public:

	seq_astnode(){
		astnode_type = seq_astnode_type;
	}

    vector<statement_astnode*> statements;

	void print(int blanks){

		cout << "{" << endl;
		cout << "\"seq\": [" << endl;

		for (int i=0; i<statements.size(); i++){
			statements[i]->print(0);
			if (i < statements.size()-1){
				cout << ",";
			}
			cout << endl;
		}
		cout << endl;
		cout << "]" << endl;
		cout << "}" << endl;
	}

};

class assignS_astnode : public statement_astnode{

    public: 

    exp_astnode* left_part;
    exp_astnode* right_part;

	assignS_astnode(){
		astnode_type = assignS_astnode_type;
	}

	void print(int blanks){
		printAst("assignS", "aa", left_part, "left", right_part, "right");
	}

};

class return_astnode : public statement_astnode{ 

    public: 

    exp_astnode* return_statement;

	return_astnode(){
		astnode_type = return_astnode_type;
	}

	void print(int blanks){
		// printAst("return", "a", return_statement, "return");
		cout << "{" << endl;
		cout << "\"return\": " << endl;
		return_statement->print(0);
		cout << "}" << endl;
	}

};

class if_astnode : public statement_astnode{ 

    public:

    exp_astnode* condition;
	statement_astnode* then_statement;
	statement_astnode* else_statement;

	if_astnode(){
		astnode_type = if_astnode_type;
	}

	void print(int blanks){
		printAst("if", "aaa", condition, "cond", then_statement, "then", else_statement, "else");
	}

};

class while_astnode : public statement_astnode{ 

	public:

	exp_astnode* condition;
	statement_astnode* then_statement;

	while_astnode(){
		astnode_type = while_astnode_type;
	}

	void print(int blanks){
		printAst("while", "aa", condition, "cond", then_statement, "stmt");
	}

};

class for_astnode : public statement_astnode{ 

	public:

	exp_astnode* init_condition;
	exp_astnode* guard_condition;
	exp_astnode* step_condition;
	statement_astnode* then_statement;

	for_astnode(){
		astnode_type = for_astnode_type;
	}

	void print(int blanks){
		printAst("for", "aaaa", init_condition, "init", guard_condition, "guard", step_condition, "step", then_statement, "body");	
	}
};

class identifier_astnode : public ref_astnode{ 

	public:

	string identifier_name;

	identifier_astnode(){
		astnode_type = identifier_astnode_type;
	}

	void print(int blanks){
		// printAst("identifier", "s", identifier_name.c_str(), "identifier");
		cout << "{" << endl;
		cout << "\"identifier\": " << "\"" << identifier_name.c_str() << "\"" << endl;
		cout<< "}" << endl;
	}

};

class proccall_astnode : public statement_astnode{ 

	public:

	identifier_astnode* proc_name;
	vector<exp_astnode*> params;

	proccall_astnode(){
		astnode_type = proccall_astnode_type;
	}

	void print(int blanks){
		printAst("proccall", "al", proc_name, "fname", params, "params");
	}

};

class arrayref_astnode : public ref_astnode{ 

	public:

	exp_astnode* array_name;
	exp_astnode* array_index;

	arrayref_astnode(){
		astnode_type = array_astnode_type;
	}

	void print(int blanks){
		printAst("arrayref", "aa", array_name, "array", array_index, "index");
	}

};

class member_astnode : public ref_astnode{ 

	public:

	exp_astnode* struct_name;
	identifier_astnode* struct_field;

	member_astnode(){
		astnode_type = member_astnode_type;
	}

	void print(int blanks){
		printAst("member", "aa", struct_name, "struct", struct_field, "field");
	}

};

class arrow_astnode : public ref_astnode{ 

	public:

	exp_astnode* pointer_name;
	identifier_astnode* pointer_field;

	arrow_astnode(){
		astnode_type = arrow_astnode_type;
	}

	void print(int blanks){
		printAst("arrow", "aa", pointer_name, "pointer", pointer_field, "field");
	}

};

class op_binary_astnode : public exp_astnode{

	public:
	
	string op;
	exp_astnode* left_exp;
	exp_astnode* right_exp;

	op_binary_astnode(){
		astnode_type = binary_op_astnode_type;
	}

	void print(int blanks){
		printAst("op_binary", "saa", op.c_str(), "op", left_exp, "left", right_exp, "right");
	}

};

class op_unary_astnode : public exp_astnode{
    
	public:

	string op;
	exp_astnode* exp;

	op_unary_astnode(){
		astnode_type = unary_op_astnode_type;
	}

	void print(int blanks){
		printAst("op_unary", "sa", op.c_str(), "op", exp, "child");
	}

};

class assignE_astnode : public exp_astnode{
    
	public:

	exp_astnode* left_exp;
	exp_astnode* right_exp;

	assignE_astnode(){
		astnode_type = assignE_astnode_type;
	}

	void print(int blanks){
		printAst("assignE", "aa", left_exp, "left", right_exp, "right");
	}

};

class funccall_astnode : public exp_astnode{
    
	public:

	identifier_astnode* func_name;
	vector<exp_astnode*> params;

	funccall_astnode(){
		astnode_type = function_call_astnode_type;
	}

	void print(int blanks){
		printAst("funcall", "al", func_name, "fname", params, "params");
	}

};

class intconst_astnode : public exp_astnode{

    public:

	string value;

	intconst_astnode(){
		astnode_type = int_constant_astnode_type;
	}

	void print(int blanks){
		// printAst("intconst", "i", stoi(value), "num");
		cout << "{" << endl;
		cout << "\"intconst\": " <<  stoi(value.c_str());
		cout << "}" << endl;
	}


};

class floatconst_astnode : public exp_astnode{
    
	public:

	string value;

	floatconst_astnode(){
		astnode_type = float_constant_astnode_type;
	}

	void print(int blanks){
		// float value_doubled = stof(value.c_str());
		// printAst("floatconst", "f", value_doubled, "num");
		cout << "{" << endl;
		cout << "\"floatconst\": " <<  stod(value.c_str());
		cout << "}" << endl;
	}

};

class stringconst_astnode : public exp_astnode{
    
	public:

	string value;

	stringconst_astnode(){
		astnode_type = string_constant_astnode_type;
	}

	void print(int blanks){
		// printAst("string", "s", value.c_str(), "string");
		cout << "{" << endl;
		cout << "\"stringconst\": " << value.c_str() << endl;
		cout << "}" << endl;
	}

};






