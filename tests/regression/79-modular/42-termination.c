// PARAM: --enable modular --set ana.modular.funs "['freadptrinc', 'freadseek']" --set ana.activated[+] "'modular_queries'" --set ana.activated[+] "'is_modular'" --set ana.activated[+] "'written'" --set ana.activated[+] "'read'" --set ana.activated[+] "'used_globals'" --set ana.activated[+] "'startstate'"
struct _IO_FILE
{
	char *_IO_read_ptr;
};
struct _IO_FILE freadptrinc_fp;
unsigned long freadptrinc_increment;

void freadptrinc()
{
	freadptrinc_fp._IO_read_ptr += freadptrinc_increment;
}

void freadseek(void)
{
	unsigned long total_buffered;
	// Evaluation of this loop used to not terminate
	while (total_buffered > 0)
	{
		{
			freadptrinc();
		}
	}
}

