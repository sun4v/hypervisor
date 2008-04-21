/*
* ========== Copyright Header Begin ==========================================
* 
* OpenSPARC T1 Processor File: make_prom.c
* Copyright (c) 2006 Sun Microsystems, Inc.  All Rights Reserved.
* DO NOT ALTER OR REMOVE COPYRIGHT NOTICES.
* 
* The above named program is free software; you can redistribute it and/or
* modify it under the terms of the GNU General Public
* License version 2 as published by the Free Software Foundation.
* 
* The above named program is distributed in the hope that it will be 
* useful, but WITHOUT ANY WARRANTY; without even the implied warranty of
* MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
* General Public License for more details.
* 
* You should have received a copy of the GNU General Public
* License along with this work; if not, write to the Free Software
* Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA 02110-1301, USA.
* 
* ========== Copyright Header End ============================================
*/
#include <sys/types.h>
#include <stdio.h>
#include <stdlib.h>
#include <strings.h>
#include <errno.h>
#include <inttypes.h>

#include <unistd.h>
#include <fcntl.h>
#include <sys/stat.h>
#include <sys/mman.h>



/*
 * Notes:
 *
 *     1) This file is used to create prom.bin for running stand-alone progams
 *        on top of the hypervisor.
 *
 *     2) For running OBP, openboot.bin needs to be added to the list of files
 *        at offset 0x80000 and of max_file_size 0x70000
 */


static char  *prom_filename;


struct file_info {
    char     *name;
    size_t    prom_file_offset;
    size_t    max_file_size;
};

#define N_FILES 4

struct file_info files[N_FILES] = {
    { "reset.bin",    0x00000, 0x20000 },
    { "q.bin",        0x20000, 0x60000 },
    { "guest-pd.bin", 0xf0000, 0x08000 },
    { "hv-pd.bin",    0xf8000, 0x04000 }
};


static void
cleanup_and_exit(int status)
{
    unlink(prom_filename);
    exit(status);
}


/*
 * Always reads "nbyte" bytes unless end of file encountered.
 */

static ssize_t
read_all(int ifd, char *buf, size_t nbyte, const char *filename)
{
    size_t   rem_bytes, bytes_read;
    ssize_t  read_result;

    bytes_read = 0;
    rem_bytes  = nbyte;

    while (rem_bytes) {
	read_result = read(ifd, &buf[bytes_read], rem_bytes);
	if (read_result < 0) {
	    perror("ERROR: read ");
	    fprintf(stderr, "ERROR: Couldn't read file \"%s\" \n", filename);
	    cleanup_and_exit(EXIT_FAILURE);
	}
	if (read_result == 0) {
	    return bytes_read;
	}

	rem_bytes  -= read_result;
	bytes_read += read_result;
    }

    return bytes_read;
}

static size_t
get_file_size(const char *filename)
{
    struct stat stat_buf;

    if (stat(filename, &stat_buf) < 0) {
	perror("ERROR: stat");
	fprintf(stderr, "ERROR: Couldn't stat file \"%s\" \n", filename);
	cleanup_and_exit(EXIT_FAILURE);
    }

    return stat_buf.st_size;
}

static void
read_file(char *filename, char *buf, size_t buf_size)
{
    int     fd;
    size_t  file_size;

    struct stat  stat_buf;

    fd = open(filename, O_RDONLY);
    if (fd < 0) {
	perror("ERROR: open");
	printf("ERROR: error opening file \"%s\" for reading. \n", filename);
	cleanup_and_exit(EXIT_FAILURE);
    }

    file_size = get_file_size(filename);

    if (file_size > buf_size) {
	fprintf(stderr, "ERROR: filename %s: file_size 0x%" PRIx64 " is larger than allocated space 0x%" PRIx64 " \n",
				filename, (uint64_t) file_size, (uint64_t) buf_size);
	cleanup_and_exit(EXIT_FAILURE);
    }

    read_all(fd, buf, file_size, filename);
    close(fd);

    return;
}


#define PROM_FILE_SIZE   (1024 * 1024)

int
main(int argc, char *argv[])
{
    int    fd;
    off_t  prom_file_offset;

    size_t bytes_written;
    off_t  lseek_result;

    char   buf[1];


    if (argc != 2) {
	fprintf(stderr, "ERROR: usage: %s prom_filename \n", argv[0]);
	exit(EXIT_FAILURE);
    }

    prom_filename = argv[1];
    
    fd = open(prom_filename, O_RDWR|O_CREAT|O_TRUNC, 0666);
    if (fd < 0) {
	perror("ERROR: open");
	fprintf(stderr, "ERROR: Couldn't open/creat file \"%s\" for reading/writing \n", prom_filename);
	cleanup_and_exit(EXIT_FAILURE);
    }

    prom_file_offset = PROM_FILE_SIZE - 1;
    lseek_result = lseek(fd, prom_file_offset, SEEK_SET);
    if (lseek_result == (off_t) -1) {
	perror("ERROR: lseek");
	fprintf(stderr, "ERROR: lseek failed trying to set file pointer to 0x%" PRIx64 " \n", (uint64_t)prom_file_offset);
	cleanup_and_exit(EXIT_FAILURE);
    }

    buf[0] = 0;
    bytes_written = write(fd, buf, 1);
    if (bytes_written < 0) {
	perror("ERROR: write ");
	fprintf(stderr, "ERROR: Couldn't write to file \"%s\" \n", prom_filename);
	cleanup_and_exit(EXIT_FAILURE);
    }

    caddr_t addr = mmap(0, PROM_FILE_SIZE, PROT_READ|PROT_WRITE, MAP_SHARED, fd, 0);
    if (addr == MAP_FAILED) {
	perror("ERROR: mmap");
	cleanup_and_exit(EXIT_FAILURE);
    }
    memset(addr, 0, PROM_FILE_SIZE);

    for (int i=0; i<N_FILES; i++) {
	read_file(files[i].name, (addr + files[i].prom_file_offset), files[i].max_file_size);
    }

    munmap(addr, PROM_FILE_SIZE);

    close(fd);

    return 0;
}


