#include "loadmtx.hpp"

#include <vector>
#include <string>
#include <iostream>
#include <iomanip>

using namespace std;

int main(int argc, char *argv[]){
    
    vector<vector<double>> mat = loadMTXFile("../data/cage4.mtx");

    int rowNum = mat.size();
    int colNum = mat[0].size();

    for(int i = 0; i < rowNum; i++){
        for(int j = 0; j < colNum; j++){
            cout << setw(10) << mat[i][j] << " ";
        }
        cout << endl;
    }
    return 0;
}