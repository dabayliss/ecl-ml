//Perceptron Example
//
import ML;
d := dataset([{1,0, 0, 1, 1}, {2,0, 1, 1, 1}, {3,1, 0, 1, 1}, {4,1, 1, 0, 0}],
{ unsigned id,unsigned a, unsigned b, unsigned c, unsigned d });
ML.ToField(d,o);
o1 := ML.Discretize.ByRounding(o)(id<5);
ML.Classify.Perceptron(1).LearnD(o1(Number<=2),o1(number>=3));
ML.Classify.Perceptron(1).LearnD(o1(Number<=2),o1(number>=3));
ML.Classify.Perceptron(1).LearnD(o1(Number<=2),o1(number>=3));
ML.Classify.Perceptron(1).LearnD(o1(Number<=2),o1(number>=3));
ML.Classify.Perceptron(1).LearnD(o1(Number<=2),o1(number>=3));
ML.Classify.Perceptron(1).LearnD(o1(Number<=2),o1(number>=3));
ML.Classify.Perceptron(1).LearnD(o1(Number<=2),o1(number>=3));
ML.Classify.Perceptron(1).LearnD(o1(Number<=2),o1(number>=3));
ML.Classify.Perceptron(1).LearnD(o1(Number<=2),o1(number>=3));
