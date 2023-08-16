#include <iostream> 
#include <vector> 
#include <unordered_map> 
#include <algorithm> 
#include <string> 
#include "ast.hh"

using namespace std; 

class Node{ 
    public:
    
    string name;
    int size; 
    string type; 
    string text;
    abstract_astnode* ast;
};