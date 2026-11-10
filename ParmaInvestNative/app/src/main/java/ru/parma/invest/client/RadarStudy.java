package ru.parma.invest.client;

/**
 * PARMA INVEST: transparent, fixed research heuristic.
 * No trade execution, no future-return claims. Uses only completed daily closes.
 */
final class RadarStudy {
    static final class Result {
        final double last,min20,max20,mean20,mean60,maxDrawdown60;
        Result(double l,double lo,double hi,double avg20,double avg60,double dd) {
            last=l;min20=lo;max20=hi;mean20=avg20;mean60=avg60;maxDrawdown60=dd;
        }
    }
    private RadarStudy(){}
    static Result analyze(double[] closes) {
        if(closes==null||closes.length<60) return null;
        final int n=closes.length;
        double low=Double.POSITIVE_INFINITY,high=Double.NEGATIVE_INFINITY;
        double sum20=0.0,sum60=0.0,peak=0.0,maxDrawdown=0.0;
        for(int i=n-60;i<n;i++) {
            double v=closes[i];
            if(!Double.isFinite(v)||v<=0) return null;
            sum60+=v;
            peak=Math.max(peak,v);
            maxDrawdown=Math.max(maxDrawdown,(peak-v)*100.0/peak);
            if(i>=n-20) {
                sum20+=v;
                low=Math.min(low,v);
                high=Math.max(high,v);
            }
        }
        return new Result(closes[n-1],low,high,sum20/20.0,sum60/60.0,maxDrawdown);
    }
}
