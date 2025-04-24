from scipy.special import ndtri
import pandas as pd

def int_normalization(x):
    """Creates an Inverse Normal-Tranformation (INT) for a Pandas Series.
    Arguments:
        - x: Pandas series with the data. Can include NAs.

    Returns:
        - x_normalized: Pandas series with normalized data.
    """
    
    x_rank = x.rank()
    numerator = x_rank - 0.5 
    par = numerator/len(x)
    x_normalized = ndtri(par)
    
    return x_normalized
