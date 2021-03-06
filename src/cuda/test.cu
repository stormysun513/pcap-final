#include <iostream>
#include <cmath>

#include <thrust/device_ptr.h>
#include <cusp/csr_matrix.h>
#include <cusp/io/matrix_market.h>
#include <cusp/print.h>
#include <cusp/multiply.h>

#include "gmres.cuh"

template <class T>
struct square
{
    __host__ __device__
    T operator()(const T& x) const {
        return x * x;
    }
};

template <class T>
struct saxpy_functor : public thrust::binary_function<T, T, T>
{
    const T a;

    saxpy_functor(T _a) : a(_a) {}

    __host__ __device__
    T operator()(const T& x, const T& y) const {
        return a * x + y;
    }
};

template <class Iterator>
static float l2norm(Iterator begin, Iterator end){

    square<float>        unary_op;
    thrust::plus<float> binary_op;
    float init = 0;

    return std::sqrt(thrust::transform_reduce(begin, end, unary_op, init, binary_op));
}

template <class Iteratable>
void saxpy_fast(float a, Iteratable& X, Iteratable& Y) {
    // Y <- A * X + Y
    thrust::transform(X.begin(), X.end(), Y.begin(), Y.begin(), saxpy_functor<float>(a));
}

template <class Iterator>
void saxpy_fast(float a, Iterator xbegin, Iterator xend, Iterator ybegin){
    // Y <- A * X + Y
    thrust::transform(xbegin, xend, ybegin, ybegin, saxpy_functor<float>(a));
}

template <class Matrix>
static csr_mat_t get_csr_mat_t(Matrix& A){

    csr_mat_t csr_mat;

    csr_mat.nrow = A.num_rows;
    csr_mat.ncol = A.num_cols;
    csr_mat.nnz = A.values.size();
    csr_mat.value = thrust::raw_pointer_cast(A.values.data());
    csr_mat.cindex = thrust::raw_pointer_cast(A.column_indices.data());
    csr_mat.rowstart = thrust::raw_pointer_cast(A.row_offsets.data());

    return csr_mat;
}

template <class Vector>
static vec_t get_vec_t(Vector& x){

    vec_t vec_x;

    vec_x.value = thrust::raw_pointer_cast(x.data());
    vec_x.size = x.size();

    return vec_x;
}

static void test_matrix_setup(){

    // // create an empty sparse matrix structure (CSR format)
    // cusp::csr_matrix<int, float, cusp::device_memory> A;

    // // load a matrix stored in MatrixMarket format
    // cusp::io::read_matrix_market_file(A, "../../data/cage4.mtx");

    // // allocate storage for solution (x) and right hand side (b)
    // cusp::array1d<float, cusp::device_memory> x(A.num_cols);
    // cusp::array1d<float, cusp::device_memory> b(A.num_rows, 1);

    // // get raw pointer
    // csr_mat_t csr_mati = get_csr_mat_t(A);
    // vec_t vec_x = get_vec_t(x);
    // vec_t vec_b = get_vec_t(b);
}

static void test_s_x_sqrt(){

    cusp::array1d<float, cusp::device_memory> x(10, 9);
    cusp::array1d<float, cusp::device_memory> y(10);

    float *p_x = thrust::raw_pointer_cast(x.data());
    float *p_y = thrust::raw_pointer_cast(y.data());

    s_x_sqrt<<<1, 256>>>(p_y, p_x, 10);

    // it should be all 3s
    cusp::print(y);
}

static void test_s_x_div_a(){

    cusp::array1d<float, cusp::device_memory> x(10, 9);
    cusp::array1d<float, cusp::device_memory> y(10);
    cusp::array1d<float, cusp::device_memory> a(1, 2);

    float *p_x = thrust::raw_pointer_cast(x.data());
    float *p_y = thrust::raw_pointer_cast(y.data());
    float *p_a = thrust::raw_pointer_cast(a.data());

    s_x_div_a<<<1, 256>>>(p_y, p_x, p_a, 10);

    // it should be all 4.5s
    cusp::print(y);
}


static void test_s_x_dot_y(){

    cusp::array1d<float, cusp::device_memory> x(10);
    cusp::array1d<float, cusp::device_memory> y(10);
    cusp::array1d<float, cusp::device_memory> res(1);

    for(int i = 0; i < 10; i++){
        x[i] = i+1;
        y[i] = i+1;
    }

    float *p_x = thrust::raw_pointer_cast(x.data());
    float *p_y = thrust::raw_pointer_cast(y.data());
    float *p_res = thrust::raw_pointer_cast(res.data());

    s_x_dot_y<<<1, 256>>>(p_res, p_y, p_x, 10);

    // it should be 91
    cusp::print(res);
}

static void test_s_x_sub_ay(){

    // void s_x_sub_ay(float *x, float *y, float *a, int N){

    cusp::array1d<float, cusp::device_memory> x(10, 9);
    cusp::array1d<float, cusp::device_memory> y(10, 2);
    cusp::array1d<float, cusp::device_memory> a(1, 2);

    float *p_x = thrust::raw_pointer_cast(x.data());
    float *p_y = thrust::raw_pointer_cast(y.data());
    float *p_a = thrust::raw_pointer_cast(a.data());

    s_x_sub_ay<<<1, 256>>>(p_x, p_y, p_a, 10);

    // it should be 5
    cusp::print(x);
}

static void test_s_mat_mul_x(){

    // create an empty sparse matrix structure (CSR format)
    cusp::csr_matrix<int, float, cusp::device_memory> A;

    // load a matrix stored in MatrixMarket format
    cusp::io::read_matrix_market_file(A, "../../data/cage4.mtx");

    cusp::array1d<float, cusp::device_memory> x(A.num_cols, 1);
    cusp::array1d<float, cusp::device_memory> y1(A.num_rows);
    cusp::array1d<float, cusp::device_memory> y2(A.num_rows);

    // get raw pointer
    csr_mat_t mat = get_csr_mat_t(A);
    float *p_x = thrust::raw_pointer_cast(x.data());
    float *p_y1 = thrust::raw_pointer_cast(y1.data());

    s_mat_mul_x<<<1, 256>>>(p_y1, mat, p_x);

    // y1 should be the same as y2
    cusp::print(y1);

    cusp::multiply(A, x, y2);

    cusp::print(y2);
}

static void test_gmres_update_x(){
    //(float *x, float *V, float *y, int m, int N);

}

static void test_gmres_compute_r0(){
    //(float *r0, csr_mat_t mat, float *x, vec_t vec, float *beta);

}

static void test_thrust_reduction(){

    cusp::array1d<float, cusp::device_memory> x(10);

    for(int i = 0; i < 10; i++){
        int num = i+1;
        x[i] = num*num;
    }

    //float *p_x = thrust::raw_pointer_cast(x.data());
    thrust::device_ptr<float> dp_x = x.data();

    //float res = thrust::reduce(x.begin(), x.end());
    float res = thrust::reduce(dp_x, dp_x+10);

    std::cout << "Thrust reduce result: " << res << std::endl;
}

static void test_thrust_dot(){

    cusp::array1d<float, cusp::device_memory> x(10);
    cusp::array1d<float, cusp::device_memory> y(10);

    for(int i = 0; i < 10; i++){
        int num = i+1;
        x[i] = num*num;
        y[i] = 0;
    }
    y[9] = 0.1;

    //float *p_x = thrust::raw_pointer_cast(x.data());
    thrust::device_ptr<float> dp_x = x.data();
    thrust::device_ptr<float> dp_y = y.data();

    //float res = thrust::reduce(x.begin(), x.end());
    float res = thrust::inner_product(dp_x, dp_x+10, dp_y, 0.f);

    std::cout << "Thrust dot result: " << res << std::endl;
}

static void test_l2norm(){

    cusp::array1d<float, cusp::device_memory> x(10);
    for(int i = 0; i < 10; i++){
        int num = i+1;
        x[i] = num;
    }

    float res = l2norm(x.begin(), x.end());
    std::cout << "L2 norm result: " << res << std::endl;
}

static void test_saxpy(){

    cusp::array1d<float, cusp::device_memory> x(10, 2);
    cusp::array1d<float, cusp::device_memory> y(10, 1);

    thrust::device_ptr<float> dp_x = x.data();
    thrust::device_ptr<float> dp_y = y.data();

    //saxpy_fast(3, x, y);
    //saxpy_fast(3, x.begin(), x.end(), y.begin());
    saxpy_fast(3, dp_x, dp_x+10, dp_y);

    cusp::print(y);
}

int main(){

    std::cout << "\nTest program: \n\n";

    //test_s_x_sqrt();
    //test_s_x_div_a();
    //test_s_x_dot_y();
    //test_s_x_sub_ay();

    // test_thrust_reduction();
    test_thrust_dot();
    //test_l2norm();
    //test_saxpy();

    return 0;
}
