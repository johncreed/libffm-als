#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <ctype.h>
#include <errno.h>

#include "mex.h"

#define DEBUG

#ifdef MX_API_VER
#if MX_API_VER < 0x07030000
typedef int mwIndex;
#endif 
#endif 
#ifndef max
#define max(x,y) (((x)>(y))?(x):(y))
#endif
#ifndef min
#define min(x,y) (((x)<(y))?(x):(y))
#endif

void exit_with_help()
{
	mexPrintf(
	"Usage: [label_vector, instance_matrix] = libsvmread('filename');\n"
	);
}

static void fake_answer(int nlhs, mxArray *plhs[])
{
	int i;
	for(i=0;i<nlhs;i++)
		plhs[i] = mxCreateDoubleMatrix(0, 0, mxREAL);
}

static char *line;
static int max_line_len;

static char* readline(FILE *input)
{
	int len;
	
	if(fgets(line,max_line_len,input) == NULL){
		return NULL;
	}

	while(strrchr(line,'\n') == NULL)
	{
		max_line_len *= 2;
		line = (char *) realloc(line, max_line_len);
		len = (int) strlen(line);
		if(fgets(line+len,max_line_len-len,input) == NULL)
			break;
	}
	return line;
}

mxArray* invert_sparse_matrix(mxArray *mx){
		mxArray *lhs[1], *rhs[1]; 
		rhs[0] = mx;
		if(mexCallMATLAB(1, lhs, 1, rhs, "transpose"))
		{
			mexPrintf("Error: cannot transpose problem\n");
			return mx;
		}
		return lhs[0];
}


// read in a problem (in libsvm format)
void read_problem(const char *filename, int nlhs, mxArray *plhs[])
{
	size_t f=0, l=0;
	size_t* nnzs;
	int *max_indexs;
	size_t max_f = 2;
	nnzs = (size_t *) malloc( max_f * sizeof(size_t));
	max_indexs = (int *) malloc( max_f * sizeof(int));
	
	for(int i = 0; i < max_f; i++){
		nnzs[i] = 0;
		max_indexs[i] = -1;
	}
	max_line_len = 1024;
	line = (char *) malloc(max_line_len*sizeof(char));

	char *endptr;
	FILE *fp = fopen(filename, "r");
	while(readline(fp) != NULL){
		char *field, *idx, *val;
		size_t f_val, idx_val; 
#ifdef DEBUG
		mexPrintf("line: %s", line);
#endif
		strtok(line, " \t"); // Skip label
		while(1){
			field = strtok(NULL,":");
			idx = strtok(NULL,":");
			val = strtok(NULL," \t");
			if( val == NULL)
				break;

			errno = 0;
			f_val = (size_t) strtol(field, &endptr, 10);
			idx_val = (int) strtol(idx, &endptr, 10);
#ifdef DEBUG
			mexPrintf("f_val %d, idx_val %d\n", f_val, idx_val);
#endif
			
			f = max(f, f_val + 1);
			if(f > max_f){
				max_f *= 2;
				nnzs = (size_t *) realloc(nnzs, max_f * sizeof(size_t));
				max_indexs = (int *) realloc(max_indexs, max_f * sizeof(int));
				for(int i = max_f / 2; i < max_f; i++){
					nnzs[i] = 0;
					max_indexs[i] = -1;
				}
			}
			nnzs[f_val]++;
			max_indexs[f_val] = max(max_indexs[f_val], (int) idx_val);
		}
		l++;
	}
	rewind(fp);

#ifdef DEBUG
	mexPrintf("Finish read meta.\n");
	mexPrintf("f: %d, l: %d\n", f, l );
	for(size_t i = 0; i < f; i++){
		mexPrintf("%d, nnz %d, max_idx %d\n", i, nnzs[i], max_indexs[i]);
	}
#endif

	plhs[0] = mxCreateDoubleMatrix(l, 1, mxREAL);
	mxArray *sp_m[f];
	for(size_t i = 0; i < f; i++)
		sp_m[i] = mxCreateSparse(max_indexs[i] + 1, l, nnzs[i], mxREAL);

	double *labels, *values[f], nnz_counts[f];
	mwIndex  *ir[f], *jc[f];
	labels = mxGetPr(plhs[0]);
	for(size_t i = 0; i < f; i++){
		values[i] = mxGetPr(sp_m[i]);
		ir[i] = mxGetIr(sp_m[i]);
		jc[i] = mxGetJc(sp_m[i]);
		nnz_counts[i] = 0;
	}
#ifdef DEBUG
	mexPrintf("Finish init matrixes\n");
#endif

	for(size_t i=0;i<l;i++)
	{
		char *field, *idx, *val, *label;
		size_t f_val, idx_val;
		double val_val;
		for(size_t j = 0; j < f; j++)
			jc[j][i] = nnz_counts[j];

		readline(fp);
		label = strtok(line," \t\n");
		labels[i] = strtod(label,&endptr);
		while(1)
		{
			field = strtok(NULL,":");
			idx = strtok(NULL,":");
			val = strtok(NULL," \t");
			if(val == NULL)
				break;
			
			f_val = (size_t) strtol(field, &endptr, 10);
			idx_val = (size_t) strtol(idx, &endptr, 10);
			val_val = (size_t) strtod(val, &endptr);

			size_t nnz_count = nnz_counts[f_val];
			ir[f_val][nnz_count] = (mwIndex) idx_val;
			values[f_val][nnz_count] = strtod(val,&endptr);
			++nnz_counts[f_val];
		}
	}
	for(size_t i = 0; i < f ; i++)
		jc[i][l] = nnz_counts[i];

#ifdef DEBUG
	mexPrintf("Finish insert matrixes\n");
#endif

	plhs[1] = mxCreateCellMatrix(1, f);
	mwIndex loc[2];
	loc[0] = (mwIndex) 0;
	for(size_t i = 0; i < f; i++){
		loc[1] = (mwIndex) i;
		sp_m[i] = invert_sparse_matrix(sp_m[i]);
		mxSetCell(plhs[1], mxCalcSingleSubscript(plhs[1], 2, loc), sp_m[i]);
	}
}

void mexFunction( int nlhs, mxArray *plhs[],
		int nrhs, const mxArray *prhs[] )
{
	char filename[256];

	if(nrhs != 1 || nlhs != 2)
	{
		exit_with_help();
		fake_answer(nlhs, plhs);
		return;
	}

	mxGetString(prhs[0], filename, mxGetN(prhs[0]) + 1);

	if(filename == NULL)
	{
		mexPrintf("Error: filename is NULL\n");
		return;
	}

#ifdef DEBUG
	mexPrintf("Start Read.\n");
#endif
	read_problem(filename, nlhs, plhs);

	return;
}

