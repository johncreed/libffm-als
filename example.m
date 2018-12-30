% compile the libsvmread.cpp
make;

% set model parameters
%lambda = 0.0625; d = 32;

% set training algorithm's parameters
epsilon = 0.0001; do_pcond = false; sub_rate = 1;

%tr='avazu-app.10000.tr.cvt';
%te='avazu-app.1000.va.cvt';
%d=8;
%lambda=2^-6;

fprintf('Start parse.\n');
% prepare training and test data sets
[y,X] = libffmread(tr);
[y_test,X_test] = libffmread(te);
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
[W,H] = ffm_train(y, X, f, lambda, d, epsilon, do_pcond, sub_rate, y_test, X_test);
fprintf('End train.\n');

% do prediction
y_tilde = ffm_predict(X_test, f, W, H);
expyy = exp(y_test.*y_tilde);
loss = sum(log1p(1./expyy)) / size(X_test{1},1);
display(sprintf('logloss: %f', loss));
exit;
