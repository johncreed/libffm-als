% compile the libsvmread.cpp
make;

% set model parameters
lambda = 0.0625; d = 4;

% set training algorithm's parameters
epsilon = 0.01; do_pcond = false; sub_rate = 0.1;

fprintf('Start parse.\n');
% prepare training and test data sets
[y,X] = libffmread('fourclass_scale.tr.cvt');
[y_test,X_test] = libffmread('fourclass_scale.te.cvt');

fprintf('End parse.\n');

f = max(size(X,2), size(X_test,2));
for f_i = 1:f
	n = max(size(X{f_i},2),size(X_test{f_i},2));
	[i,j,s] = find(X{f_i});
	X{f_i} = sparse(i,j,s,size(X{f_i},1),n);
	[i,j,s] = find(X_test{f_i});
	X_test{f_i} = sparse(i,j,s,size(X_test{f_i},1),n);
end
% learn an FM model
fprintf('Start train.\n');
[W,H] = ffm_train(y, X, f, lambda, d, epsilon, do_pcond, sub_rate);
fprintf('End train.\n');

% do prediction
%y_tilde = fm_predict(X_test, w, U, V);
%display(sprintf('test accuracy: %f', sum(sign(y_tilde) == y_test)/size(y_test,1)));
