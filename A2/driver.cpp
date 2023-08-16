
#include "scanner.hh"
#include "parser.tab.hh"
#include <fstream>
using namespace std;

SymbTab gst, gstfun, gststruct; 
string filename;
extern std::map<string,abstract_astnode*> ast;
// std::map<std::string, datatype> predefined {
//             {"printf", createtype(VOID_TYPE)},
//             {"scanf", createtype(VOID_TYPE)},
//             {"mod", createtype(INT_TYPE)}
//         };
int main(int argc, char **argv)
{
	using namespace std;
	fstream in_file, out_file;
	

	in_file.open(argv[1], ios::in);

	IPL::Scanner scanner(in_file);

	IPL::Parser parser(scanner);

#ifdef YYDEBUG
	parser.set_debug_level(1);
#endif
parser.parse();
// create gstfun with function entries only

for (const auto &entry : gst.Entries)
{
	if (entry.second->var_func == "fun")
	gstfun.Entries.insert({entry.first, entry.second});
}
// create gststruct with struct entries only

for (const auto &entry : gst.Entries)
{
	if (entry.second->var_func == "struct")
	gststruct.Entries.insert({entry.first, entry.second});
}
// start the JSON printing

cout << "{\"globalST\": " << endl;
gst.printgst();
cout << "," << endl;

cout << "  \"structs\": [" << endl;
for (auto it = gststruct.Entries.begin(); it != gststruct.Entries.end(); ++it)

{   cout << "{" << endl;
	cout << "\"name\": " << "\"" << it->first << "\"," << endl;
	cout << "\"localST\": " << endl;
	it->second->symbol_table->print();
	cout << "}" << endl;
	if (next(it,1) != gststruct.Entries.end()) 
	cout << "," << endl;
}
cout << "]," << endl;
cout << "  \"functions\": [" << endl;

for (auto it = gstfun.Entries.begin(); it != gstfun.Entries.end(); ++it)

{
	cout << "{" << endl;
	cout << "\"name\": " << "\"" << it->first << "\"," << endl;
	cout << "\"localST\": " << endl;
	it->second->symbol_table->print();
	cout << "," << endl;
	cout << "\"ast\": " << endl;
	ast[it->first]->print(0);
	cout << "}" << endl;
	if (next(it,1) != gstfun.Entries.end()) cout << "," << endl;
	
}
	cout << "]" << endl;
	cout << "}" << endl;

	fclose(stdout);
}