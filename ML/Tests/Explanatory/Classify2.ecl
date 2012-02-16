//Perceptron Example
// Shows the perceptron following the steps of the Wikipedia example on perceptrons
import ML;
d := dataset([{1,0, 0, 1, 1}, {2,0, 1, 1, 1}, {3,1, 0, 1, 1}, {4,1, 1, 0, 0}],
{ unsigned id,unsigned a, unsigned b, unsigned c, unsigned d });
ML.ToField(d,o);
o1 := ML.Discretize.ByRounding(o)(id<5);
ML.Classify.Perceptron(1).LearnD(o1(Number<=2),o1(number>=3));
ML.Classify.Perceptron(2).LearnD(o1(Number<=2),o1(number>=3));
ML.Classify.Perceptron(3).LearnD(o1(Number<=2),o1(number>=3));
ML.Classify.Perceptron(4).LearnD(o1(Number<=2),o1(number>=3));
ML.Classify.Perceptron(5).LearnD(o1(Number<=2),o1(number>=3));
ML.Classify.Perceptron(6).LearnD(o1(Number<=2),o1(number>=3));
ML.Classify.Perceptron(7).LearnD(o1(Number<=2),o1(number>=3));
ML.Classify.Perceptron(8).LearnD(o1(Number<=2),o1(number>=3));
ML.Classify.Perceptron(9).LearnD(o1(Number<=2),o1(number>=3));
