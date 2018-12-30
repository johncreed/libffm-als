function y_tilde = ffm_predict(X, f, W, H)
% Predict the input instances.
% function y_tilde = fm_predict(X, f, U, V)
% Inputs:
%   X: training instances. X is an l-by-n matrix if you have l training instances in a n-dimensional feature space.
%   f: number of field.
%   U, V: the interaction (d-by-n) matrices.
% Output:
%   y_tilde: prediction values of the input instances, an l-dimensional column vector.
	y_tilde = zeros(size(X{1},1), 1); 
	for fi = 1:f
		for fj = fi:f
			[idx] = index_cvt(fi, fj, f);
			y_tilde = y_tilde + sum((W{idx}*X{fi}').*(H{idx}*X{fj}'),1)';
		end
	end
end

function [idx] = index_cvt(f1,f2,f)
	idx = (f + (f - (f1 - 1))) * (f1) / 2 -(f - f2);
end
