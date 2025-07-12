# import libraries
import pandas
import numpy
from sklearn.utils import resample
from sklearn.metrics import accuracy_score
from matplotlib import pyplot as plt

# load dataset
x = numpy.array([0.051413713695242245,
                 0.22579217192094844,
                 0.07920050109862008,
                 0.06302994063553866,
                 0.03404794505453599,
                 0.22434272370859898,
                 0.0564119934520643,
                 -0.1547477704624718,
                 0.3840121502229207,
                 0.15931313012602968,
                 0.471512078583098,
                 0.08858345032234755,
                 -0.12707374621087222])

# configure bootstrap
n_iterations = 1000 # here k=no. of bootstrapped samples
n_size = int(len(x))

# run bootstrap
medians = list()
for i in range(n_iterations):
    s = resample(x, n_samples=n_size);
    m = numpy.median(s);
    medians.append(m)

# plot scores
plt.hist(medians)
plt.show()

# confidence intervals
alpha = 0.95
p = ((1.0-alpha)/2.0) * 100
lower =  numpy.percentile(medians, p)
p = (alpha+((1.0-alpha)/2.0)) * 100
upper =  numpy.percentile(medians, p)

print(f"\n{alpha*100} confidence interval {lower} and {upper}")