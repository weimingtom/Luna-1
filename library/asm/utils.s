	.text
# Fonctions utiles à la compilation, pour alléger le compilateur
	.global	compare
compare:
	mov	%rsi, %rcx
	and	$7, %rcx
	cmp	$2, %rcx
	jz	comp_string
	cmp	%rsi, %rdi
	jz	res_t
	mov	$1, %rsi
	ret
res_t:	mov	$9, %rsi
	ret

comp_string:
	sar	$3, %rsi
	sar	$3, %rdi
	add	$8, %rsi
	add	$8, %rdi
cp_lp:	xor	%rcx, %rcx
	mov	(%rdi), %cl
	cmp	(%rsi), %cl
	jnz	cp_f
	cmp	$0, %cl
	jz	cp_t
	cmpl	$0, (%rsi)
	jz	cp_f
	inc	%rsi
	inc	%rdi
	jmp	cp_lp
cp_f:	mov	$1, %rsi
	ret
cp_t:	cmpl	$0, (%rsi)
	jnz	cp_f
	mov	$9, %rsi
	ret

	.global	index
index:
	sar	$3, %r9
	mov	8(%r9), %rdx
ix_lp:	cmp	$17, %rdx
	jz	ix_nl
	sar	$3, %rdx
	mov	(%rdx), %rsi
	mov	%r8, %rdi
	call	compare
	lea	8(%rdx), %r9
	mov	8(%r9), %rdx
	cmp	$9, %rsi
	jz	ix_ad
	jmp	ix_lp
ix_ad:	lea	(%r9), %rsi
	ret
ix_nl:	lea	8(%r9), %rsi
	ret

	.global new
new:
	call	index
	cmp	$17, (%rsi)
	jnz	nw_rt
	mov	%rbp, (%rsi)
	mov	%r8, (%rbp)
	lea	8(%rbp), %rsi
	movq	$17, 16(%rbp)
	add	$24, %rbp
nw_rt:	ret

	.global check
check:
	sar	$3, %rsi
	lea	8(%rsi), %rdi
	xor	%rcx, %rcx
ck_lp:	cmp	$17, (%rdi)
	jz	ck_en
	inc	%rcx
	mov	(%rdi), %rdx
	sar	$3, %rdx
	cmp	$17, 8(%rdx)
	jnz	ck_rm
	mov	16(%rdx), %r8
	mov	%r8, (%rdi)
	dec	%rcx
ck_rm:	mov	24(%rdi), %rdi
	jmp	ck_lp
ck_en:	mov	%rcx, (%rsi)
	ret