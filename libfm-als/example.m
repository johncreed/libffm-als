% compile the libsvmread.cpp
make;

% set model parameters
%lambda_w = 0.0625; lambda_U = 4; lambda_V = 4; d = 8;
lambda_U = lambda; lambda_V = lambda; lambda_w = 0.0625;

% set training algorithm's parameters
epsilon = 0.01; do_pcond = false; sub_rate = 1;

% prepare training and test data sets
[y,X] = libsvmread(tr);
[y_test,X_test] = libsvmread(te);

n = max(size(X,2),size(X_test,2));
[i,j,s] = find(X);
X = sparse(i,j,s,size(X,1),n);
[i,j,s] = find(X_test);
X_test = sparse(i,j,s,size(X_test,1),n);

% learn an FM model
[U, V] = fm_train(y, X, lambda_w, lambda_U, lambda_V, d, epsilon, do_pcond, sub_rate);

% do prediction
y_tilde = fm_predict(X_test, U, V);
expyy = exp(y_test.*y_tilde);
loss = sum(log1p(1./expyy)) / size(X_test,1);
display(sprintf('logloss: %f', loss));
exit;
