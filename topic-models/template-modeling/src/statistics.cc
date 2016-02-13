#include <cmath>

/* compute log of factorial */
long logFactorial( int k ) {
  
  double result = 0.0;
  while ( k > 1 ) {
    result += log( k-- );
  }
  
  return result;
  
}

/* compute poisson probability */
double logPoisson( double lambda , int k ) {
  
  return ( log(lambda) * ( (double) k ) - lambda ) - logFactorial( k );
  
}
