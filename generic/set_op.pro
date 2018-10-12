function set_op, in1, in2, $
                 union=union, $
                 intersection=intersection, int_ind=int_ind, $
                 difference=difference, diff_ind=diff_ind

A = REFORM(in1, N_ELEMENTS(in1))
B = REFORM(in2, N_ELEMENTS(in2))

C = [A,B]

u_ind = UNIQ(C, sort(C))

union = C[u_ind]

int_ind = WHERE(~HISTOGRAM([u_ind], min=0, max=N_ELEMENTS(A)-1), /null, cnt)

intersection = A[int_ind]

diff_ind = u_ind[WHERE(u_ind lt N_ELEMENTS(A),/null,cnt)]

difference = A[diff_ind]

out = list(union, intersection, difference)

return, out

end
