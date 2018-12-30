function [W,H] = ffm_train(y, X, f, lambda, d, epsilon, do_pcond, sub_rate, y_test, X_test)
% Inputs:V
%	y: training labels, an l-dimensional binary vector. Each element should be either +1 or -1.
%	X: training instances. X is an l-by-n matrix if you have l training instances in an n-dimensional feature space.
%	f: number of fields
%	lambda: the regularization coefficients of the two interaction matrices.
%	d: dimension of the latent space.
%	epsilon: stopping tolerance in (0,1). Use a larger value if the training time is too long.
%	do_pcond: a flag. Use 1/0 to enable/disable the diagonal preconditioner.
%	sub_rate: sampling rate in (0,1] to select instances for the sub-sampled Hessian matrix.
% Outputs:
%	W: colection of (Dfi-by-l) matrices.
	tic;
	max_iter = 1000;
	%num of instances
	l = size(X{1}, 1);
	%Init models
	rand('seed', 0);
	nr_block = f*(f+1)/2;
	H = cell(1,nr_block);
	W = cell(1,nr_block);
	y_tilde = zeros(l,1);
	for fi = 1:f
		for fj = fi:f
			n_i = size(X{fi},2);
			n_j = size(X{fj},2);
			[idx] = index_cvt(fi,fj,f);
			W{idx} = 2*(0.1/sqrt(d))*(rand(d,n_i)-0.5);
			H{idx} = 2*(0.1/sqrt(d))*(rand(d,n_j)-0.5);
			y_tilde = y_tilde + (sum((W{idx}*X{fi}').*(H{idx}*X{fj}'),1))';
		end
	end
	expyy = exp(y.*y_tilde);
	loss = sum(log1p(1./expyy));
	func = loss;
	for fi = 1:f
		for fj = fi:f
			[idx] = index_cvt(fi,fj,f);
			func = func + 0.5 * lambda * (sum(sum(W{idx}.*W{idx})));
			func = func + 0.5 * lambda * (sum(sum(H{idx}.*H{idx})));
		end
	end
	fprintf('time: %11.3f func: %14.6f\n', toc, func);
	G_norm_0 = 0;
	fprintf('iter          time          obj         |grad|\n');
	for k = 1:max_iter
		G_norm = 0;
		for fi = 1:f
			for fj = fi:f
				[idx] = index_cvt(fi,fj,f);
				[W{idx}, y_tilde, expyy, func, loss, nt_iters_W, G_norm_W, cg_iters_W] = update_block(y, X{fi}, W{idx}, H{idx}*X{fj}', y_tilde, expyy, func, loss, lambda, do_pcond, sub_rate);
				fprintf('W(fi,fj) : %4d, %4d time: %11.4f func: %11.3f (nt,cg) (%3d,%3d)\n', fi, fj, toc, func, nt_iters_W, cg_iters_W);
				[H{idx}, y_tilde, expyy, func, loss, nt_iters_H, G_norm_H, cg_iters_H] = update_block(y, X{fj}, H{idx}, W{idx}*X{fi}', y_tilde, expyy, func, loss, lambda, do_pcond, sub_rate);
				fprintf('H(fi,fj) : %4d, %4d time: %11.4f func: %11.3f (nt,cg) (%3d, %3d)\n', fi, fj, toc, func, nt_iters_H, cg_iters_H);
				G_norm = G_norm + sum(sum(G_norm_W.*G_norm_W)) + sum(sum(G_norm_H.*G_norm_H));
			end
		end
		G_norm = sqrt(G_norm);

		if (k == 1)
			G_norm_0 = G_norm;
		end
		if (G_norm <= epsilon*G_norm_0)
			fprintf('%.10f\n', G_norm);
			fprintf('Break with stopping condition.\n')
			break;
		end
		fprintf('iter %4d	%11.3f	  %14.6f	  %14.6f\n', k, toc, func, G_norm);
		if (k == max_iter)
			fprintf('Warning: reach max training iteration. Terminate training process.\n');
		end
		if (mod(k, 5) == 1)
			y_tilde_t = ffm_predict(X_test, f, W, H);
			expyy_t = exp(y_test.*y_tilde_t);
			loss_t = sum(log1p(1./expyy_t)) / size(X_test{1},1);
			display(sprintf('iter: %4d logloss: %f', k,loss_t));
		end
	end
end

function [idx] = index_cvt(f1,f2,f)
	idx = (f + (f - (f1 - 1))) * (f1) / 2 -(f - f2);
end

% See Algorithm 3 in the paper. 
function [U, y_tilde, expyy, f, loss, nt_iters, G_norm, total_cg_iters] = update_block(y, X, U, Q, y_tilde, expyy, f, loss, lambda, do_pcond, sub_rate)
	epsilon = 0.8;
	nu = 0.1;
	max_nt_iter = 1;
	min_step_size = 1e-20;
	l = size(X,1);
	G0_norm = 0;
	total_cg_iters = 0;
	nt_iters = 0;
	for k = 1:max_nt_iter
		G = lambda*U+Q*sparse([1:l], [1:l], -y./(1+expyy))*X;
		G_norm = sqrt(sum(sum(G.*G)));
		if (k == 1)
			G0_norm = G_norm;
		end
		if (G_norm <= epsilon*G0_norm)
			return;
		end
		nt_iters = k;
		if (k == max_nt_iter)
			%fprintf('Warning: reach newton iteration bound before gradient norm is shrinked enough.\n');
		end
		D = sparse([1:l], [1:l], expyy./(1+expyy)./(1+expyy));
		[S, cg_iters] = pcg(X, Q, G, D, lambda, do_pcond, sub_rate);
		total_cg_iters = total_cg_iters+cg_iters;
		Delta = (sum(Q'.*(X*S'),2));
		US = sum(sum(U.*S)); SS = sum(sum(S.*S)); GS = sum(sum(G.*S));
		theta = 1;
		do_line_search = false;
		fprintf('Start line search time: %11.4f\n', toc);
		while (true)
			if (theta < min_step_size)
				fprintf('Warning: step size is too small in line search. Switch to the next block of variables.\n');
				fprintf('Finish line search time: %11.4f\n', toc);
				return;
			end
			y_tilde_new = y_tilde+theta*Delta;
			expyy_new = exp(y.*y_tilde_new);
			loss_new = sum(log1p(1./expyy_new));
			f_diff = 0.5*lambda*(2*theta*US+theta*theta*SS)+loss_new-loss;
			if (f_diff <= nu*theta*GS)
				loss = loss_new;
				f = f+f_diff;
				U = U+theta*S;
				y_tilde = y_tilde_new;
				expyy = expyy_new;
				break;
			end
			theta = theta*0.5;
			do_line_search = true;
		end
		fprintf('Finish line search time: %11.4f\n', toc);
		if( do_line_search )
			fprintf('Do line search, theta: %14.6f\n', theta);
		end
	end
end

% See Algorithm 4 in the paper.
function [S, cg_iters] = pcg(X, Q, G, D, lambda, do_pcond, sub_rate)
	fprintf('Start cg time: %11.4f\n', toc);
	zeta = 0.5;
	cg_max_iter = 100;
	if (sub_rate < 1)
		l = size(X,1);
		whole = randperm(l);
		selected = sort(whole(1:max(1, floor(sub_rate*l))));
		X = X(selected,:);
		Q = Q(:,selected);
		D = D(selected,selected);
	end
	l = size(X,1);
	s_bar = zeros(size(G));
	M = ones(size(G));
	if (do_pcond)
		M = 1./sqrt(lambda+(1/sub_rate)*0.25*(Q.*Q)*(D*(X.*X)));
	end
	r = -M.*G;
	d = r;
	G0G0 = sum(sum(r.*r));
	gamma = G0G0;
	cg_iters = 0;
	while (gamma > zeta*zeta*G0G0)
		cg_iters = cg_iters+1;
		Dh = M.*d;
		z = sum(Q'.*(X*Dh'),2);
		Dh = M.*(lambda*Dh+(1/sub_rate)*Q*sparse([1:l], [1:l], D*z)*X);
		alpha = gamma/sum(sum(d.*Dh));
		s_bar = s_bar+alpha*d;
		r = r-alpha*Dh;
		gamma_new = sum(sum(r.*r));
		beta = gamma_new/gamma;
		d = r+beta*d;
		gamma = gamma_new;
		if (cg_iters >= cg_max_iter)
			fprintf('Warning: reach max CG iteration. CG process is terminated.\n');
			break;
		end
	end
	S = M.*s_bar;
	fprintf('Finish cg time: %11.4f\n', toc);
end
