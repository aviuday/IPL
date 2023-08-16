#include <iostream> 
#include <vector> 
#include <unordered_map> 
#include <algorithm> 
#include <string> 
#include <map>

using namespace std; 

class SymbTab;

struct entry{ 

    string name;
    string var_func; //change variable
    string scope; 
    int size; 
    int offset; 
    string type; 
    SymbTab* symbol_table;

};

class SymbTab{

    public: 

    map<string, entry*> Entries;

    void printinside(bool is_gst){
        for (auto i = Entries.begin(); i != Entries.end(); ++i){
            cout << "[";
            cout << "\t\"" << i->second->name << "\",";
            cout << "\t\"" << i->second->var_func << "\",";
            cout << "\t\"" << i->second->scope << "\",";
            cout << "\t" << i->second->size << ",";
            if (i->second->var_func == "struct"){
                cout << "\t\"-\",";
            }
            else{ 
                cout << "\t" << i->second->offset << ",";
            }
            cout << "\t\"" << i->second->type << "\"" << endl;
            cout << "]";

            if (next(i, 1) != Entries.end()){
                
                if(is_gst){
                    cout << "," << endl;
                }
                else{
                    cout << "\n," << endl;
                }
            }
            else{ 
                cout << endl;
            }
        }
    }

    void print(){ 
        cout << "[" << endl;
        printinside(false);
        cout << "]" << endl;
    }

    void printgst(){
        cout << "[";
        printinside(true);
        cout << "]" << endl;
    }
};

