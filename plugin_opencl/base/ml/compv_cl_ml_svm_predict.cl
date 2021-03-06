/* Copyright (C) 2016-2019 Doubango Telecom <https://www.doubango.org>
* File author: Mamadou DIOP (Doubango Telecom, France).
* License: GPLv3. For commercial license please contact us.
* Source code: https://github.com/DoubangoTelecom/compv
* WebSite: http://compv.org
*/

#if __OPENCL_VERSION__ < 120 // Starting OpenCL 1.2 it's part of Core
#pragma OPENCL EXTENSION cl_khr_fp64 : enable
#endif


#define TYP				float
#define SV_SIZ			45 // FIXME(dmi): must not be hard-coded
#define SV_SIZ_PART		3 // FIXME(dmi): must not be hard-coded round((SV_SIZ + 15) / 16)

__kernel void clCompVMachineLearningSVMPredictBinaryRBF_Part1(
	__global const TYP* matVectors, // 0
	__global const TYP* matSVs, // 1
	__global const TYP* matCoeffs, // 2
	__global TYP* matResult, // 3
	const TYP gammaMinus, // 4
	const int matSVs_cols, // 5 
	const int matResult_cols, // 6 - max(global(0)) - number of support vectors (e.g. 56958, fixed)
	const int matVectors_rows // 7 - max(global(1)) - number of features (e.g. 408, variable)
)
{
	#define matVectors_cols matSVs_cols // input vectors and SVs have same length

#if 0 // SHARED_MEMORY

	const int local_i = get_local_id(1);
    const int local_j = get_local_id(0);
	const int global_i = TS*get_group_id(1) + local_i;
	const int global_j = TS*get_group_id(0) + local_j;

	TYP sum = 0;

	__local TYP matVectors_sub[TS][TS];
    __local TYP matSVs_sub[TS][TS];
	
	const int numTiles = (matSVs_cols) / TS; // FIXME(dmi): not correct because not multiple of TS
	
	for (int t = 0; t< numTiles; ++t) {
		const int matVectors_i = TS*t + local_i;
		const int matSVs_j = TS*t + local_j;
		matVectors_sub[local_i][local_j] = matVectors[(matVectors_i * matVectors_cols) + global_i];
		matSVs_sub[local_i][local_j] = matSVs[(matSVs_j * matSVs_cols) + global_j];

		barrier(CLK_LOCAL_MEM_FENCE);

		for (int k = 0; k < TS; ++k) {
			/*if ((global_i + (TS*t) + k) < 408 && (global_j + (TS*t) + k) < 56958)*/ {
				const TYP diff = matVectors_sub[k][local_i] - matSVs_sub[local_j][k];
				 sum += (diff * diff);
				//sum = fma(diff, diff, sum);
			}
        }
 
        barrier(CLK_LOCAL_MEM_FENCE);		
	}
	matResult[(global_i * matResult_cols) + global_j] = exp(sum * gammaMinus) * matCoeffs[global_j];

#elif 0 // OCCUPANCY MAXIM

	#define SVS 7
	const int global_jsvs = get_global_id(0) * SVS; // number of support vectors (e.g. 56958) / SVS
	const int global_i = get_global_id(1); // number of inputs (e.g. 408)

	for (int j = 0; j < SVS; ++j) {
		const int global_j = global_jsvs + j;
		if (global_j < 56958) { // FIXME(dmi): hard-coded
			TYP sum = 0;

			for (int k = 0; k < matSVs_cols; ++k) {
				const TYP diff = matVectors[(global_i * matVectors_cols) + k] - matSVs[(global_j * matSVs_cols) + k];
				//sum += (diff * diff);
				sum = fma(diff, diff, sum);
			}

			matResult[(global_i * matResult_cols) + global_j] = exp(sum * gammaMinus) * matCoeffs[global_j];
		}
	}

#elif 1 // CACHED (good one)
	
	const int global_j = get_global_id(0); // number of support vectors (e.g. 56958)
	const int global_i = get_global_id(1); // number of inputs (e.g. 408)
	const int local_j = get_local_id(0);
	const int local_i = get_local_id(1);

	// "matVectors" contains the features to classify which means it will be short (N * 63) -> no need for caching

	__local TYP matSVs_sub[16][SV_SIZ]; // strange, 64 slow, 63 fast, 31 fast and 32 slow
	__local TYP matVectors_sub[16][SV_SIZ];
	if (global_j < matResult_cols) { // FIXME(dmi): add both conditions and move
		int m = (local_i * SV_SIZ_PART);
		#pragma unroll SV_SIZ_PART
		for (int k = 0; k < SV_SIZ_PART && m < SV_SIZ; ++k, ++m) {
			matSVs_sub[local_j][m] = matSVs[(global_j * matSVs_cols) + m]; // FIMXE(dmi): global_j
		}
	}
	if (global_i < matVectors_rows) {
		int n = (local_j * SV_SIZ_PART);
		#pragma unroll SV_SIZ_PART
		for (int k = 0; k < SV_SIZ_PART && n < SV_SIZ; ++k, ++n) {
			matVectors_sub[local_i][n] = matVectors[(global_i * matVectors_cols) + n]; // FIMXE(dmi): global_i
		}
	}

	barrier(CLK_LOCAL_MEM_FENCE);
	
	if (global_i < matVectors_rows && global_j < matResult_cols) {
		TYP sum = 0;
		#if 1 // Must use this version instead of unrolling the loop ourself, not recommended for Intel CPUs/GPUs
		#pragma unroll SV_SIZ
		for (int k = 0; k < SV_SIZ; ++k) {
		#else
		for (int k = 0; k < matSVs_cols; ++k) {
		#endif
			const TYP diff = matVectors_sub[local_i][k] - matSVs_sub[local_j][k];
			sum = fma(diff, diff, sum);
		}
		
		matResult[(global_i * matResult_cols) + global_j] = exp(sum * gammaMinus) * matCoeffs[global_j];
	}


#elif 0 // CACHED + OCCUPANCY MAXIM

	#define SVS 7
	int global_j = get_global_id(0) * SVS; // number of support vectors (e.g. 56958)
	int global_i = get_global_id(1); // number of inputs (e.g. 408)
	int group_j = get_group_id(0) * SVS;
	int group_i = get_group_id(1);
	int local_j = get_local_id(0);
	int local_i = get_local_id(1);

	for (int j = 0; j < SVS; ++j) {

		// "matVectors" contains the features to classify which means it will be short (N * SV_SIZ) -> no need for caching
		/*__local TYP matVectors_sub[16][SV_SIZ];
		int m = (local_j * 4);
		for (int k = 0; k < 4 && m < SV_SIZ; ++k, ++m) {
			matVectors_sub[local_i][m] = 0;//matVectors[(((group_i * 16) + local_i) * matVectors_cols) + m];
		}*/

		__local TYP matSVs_sub[16][SV_SIZ];
		/*if (global_i < 408 && global_j < 56958)*/ {
			int m = (local_i * 4);
			for (int k = 0; k < 4 && m < SV_SIZ; ++k, ++m) {
				matSVs_sub[local_j][m] = matSVs[(((group_j * 16) + local_j) * matSVs_cols) + m];
			}
		}

		barrier(CLK_LOCAL_MEM_FENCE);

		if (global_i >= 408 || global_j >= 56958) {
			return;
		}

		TYP sum = 0;

		for (int k = 0; k < matSVs_cols; ++k) {
			TYP diff = /*matVectors_sub[local_i][k]*/matVectors[(global_i * matVectors_cols) + k] - matSVs_sub[local_j][k]/*matSVs[(global_j * matSVs_cols) + k]*/;
			//sum += (diff * diff);
			sum = fma(diff, diff, sum); // fma instruction is faster
		}

		matResult[(global_i * matResult_cols) + global_j] = exp(sum * gammaMinus) * matCoeffs[global_j];

	} // for (int j = 0; j < SVS; ++j)
	
#elif 0 // TILED
#define TILE_SIZE 16
	const int global_j = get_global_id(0); // number of support vectors (e.g. 56958)
	const int global_i = get_global_id(1); // number of inputs (e.g. 408)
	const int group_j = get_group_id(0);
	const int group_i = get_group_id(1);
	const int local_j = get_local_id(0);
	const int local_i = get_local_id(1);

	__local TYP matVectors_sub[TILE_SIZE][TILE_SIZE];
	__local TYP matSVs_sub[TILE_SIZE][TILE_SIZE];

	if (local_i == 0 && local_j == 0) {
		for (int j = 0; j < TILE_SIZE; ++j) {
			for (int i = 0; i < TILE_SIZE; ++i) {
				matVectors_sub[local_i][local_j] = matVectors[(global_i * matVectors_cols) + local_j];
				matSVs_sub[local_j][local_i] = matSVs[(global_j * matSVs_cols) + local_i];
			}
		}
	}

	TYP sum = 0;

	const int numTiles = (matSVs_cols + (TILE_SIZE - 1)) / TILE_SIZE;
	for (int t = 0; t < numTiles; ++t) {
		matVectors_sub[local_i][local_j] = matVectors[(global_i * matVectors_cols) + local_j];
		matSVs_sub[local_j][local_i] = matSVs[(global_j * matSVs_cols) + local_i];
		barrier(CLK_LOCAL_MEM_FENCE);

		for (int k = 0; k < TILE_SIZE; ++k) {
			const TYP diff = matVectors_sub[local_i][k] * matSVs_sub[local_j][k];
			sum += (diff * diff);
			//sum = fma(diff, diff, sum);
		}
	}

	matResult[(global_i * matResult_cols) + global_j] = exp(sum * gammaMinus) * matCoeffs[global_j];

#elif 0 // mulAB instead of mulABt

	const int k = get_global_id(0); // Brows - 63 - k
	const int i = get_global_id(1); // Arows - 408 - i
	
	//TYP sum = 0;

	const TYP r = matVectors[(i * matVectors_cols) + k];
	for (size_t j = 0; j < 56958; ++j) {
		const TYP diff = r - matSVs[(k * matSVs_cols) + j];
		matResult[(i * matResult_cols) + j] += (diff * diff);
	}

	//for (int k = 0; k < matSVs_cols; ++k) {
	//	const TYP diff = matVectors[(global_i * matVectors_cols) + k] - matSVs[(global_j * matSVs_cols) + k];
		//sum += (diff * diff);
	//	sum = fma(diff, diff, sum);
	//}

	//matResult[(global_i * matResult_cols) + global_j] = exp(sum * gammaMinus) * matCoeffs[global_j];

#else // DEFAULT
	
	const int global_j = get_global_id(0); // number of support vectors (e.g. 56958)
	const int global_i = get_global_id(1); // number of inputs (e.g. 408)
	
	if (global_i < matVectors_rows && global_j < matResult_cols) {
		TYP sum = 0;
		for (int k = 0; k < matSVs_cols; ++k) {
			const TYP diff = matVectors[(global_i * matVectors_cols) + k] - matSVs[(global_j * matSVs_cols) + k];
			//sum += (diff * diff);
			sum = fma(diff, diff, sum);
		}

		matResult[(global_i * matResult_cols) + global_j] = exp(sum * gammaMinus) * matCoeffs[global_j];
	}
	
#endif /* SHARED_MEMORY */
	
}

/* Reduction */
#define REDUCTION_ALGO(inPtr, outPtr, inCols, inRows, outCols, rho) { \
	const int local_id0 = get_local_id(0); \
	const int global_id0 = get_global_id(0); \
	const int global_id1 = get_global_id(1); \
	\
	const int size0 = get_local_size(0); \
	\
	__local double accumulator[256]; /* FIXME(dmi): 256 must not be hard-coded */\
	accumulator[local_id0] = (global_id0 < inCols && global_id1 < inRows) ? inPtr[(global_id1 * inCols) + global_id0] : 0; \
	barrier(CLK_LOCAL_MEM_FENCE); \
	\
	for (int stride0 = (size0 >> 1); stride0 > 0; stride0 >>= 1) { \
		if (local_id0 < stride0) { \
			accumulator[local_id0] += accumulator[local_id0 + stride0]; \
		} \
		barrier(CLK_LOCAL_MEM_FENCE); \
	} \
	\
	if (local_id0 == 0 && get_local_id(1) == 0) { \
		outPtr[(global_id1 * outCols) + get_group_id(0)] = (outCols == 1) ? (accumulator[0] - rho) : accumulator[0]; \
	} \
}


// Reduction Step #1 (float -> double)
__kernel void clCompVMachineLearningSVMPredictBinaryRBF_Part2(
	__global TYP* matResult1, // 0
	__global double* matResult2, // 1
	const int matResult1_cols, // 2
	const int matResult1_rows, // 3
	const int matResult2_cols, // 4
	const double rho // 5
)
{
	REDUCTION_ALGO(matResult1, matResult2, matResult1_cols, matResult1_rows, matResult2_cols, rho);
}

// Reduction Step #2 (double -> double)
__kernel void clCompVMachineLearningSVMPredictBinaryRBF_Reduction(
	__global double* inPtr, // 0
	__global double* outPtr, // 1
	const int inCols, // 2
	const int inRows, // 3
	const int outCols, // 4
	const double rho // 5
)
{
	REDUCTION_ALGO(inPtr, outPtr, inCols, inRows, outCols, rho);
}