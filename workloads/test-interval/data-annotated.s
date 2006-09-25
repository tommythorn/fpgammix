	.file	"data.c"

# long unsigned uninitialized;
	.comm	uninitialized,8,8


# long unsigned initialized = 27;
.globl initialized
	.data
	.align 8
	.type	initialized, @object
	.size	initialized, 8
initialized:
	.quad	27


# static long unsigned uninitialized_static;
	.local	uninitialized_static
	.comm	uninitialized_static,8,8


# static long unsigned initialized_static = 27;
	.align 8
	.type	initialized_static, @object
	.size	initialized_static, 8
initialized_static:
	.quad	27


	.ident	"GCC: (GNU) 4.0.2 20050901 (prerelease) (SUSE Linux)"
	.section	.note.GNU-stack,"",@progbits
