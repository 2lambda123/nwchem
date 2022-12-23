#!/usr/bin/env bash
rm -f gamalloc.patch
cat > gamlloc.patch <<EOF
--- $1/global/src/ga_malloc.c
+++ $1/global/src/ga_malloc.c
@@ -28,7 +28,7 @@
 void* ga_malloc(Integer nelem, int type, char *name)
 {
     void *ptr;  
-    unsigned long addr;
+    size_t addr;
     Integer handle, adjust=0, bytes, item_size=GAsizeofM(pnga_type_f2c(type));
     Integer extra;
 
@@ -45,11 +45,11 @@
     if(ga_usesMA) { /* Uses Memory Allocator (MA) */
        if(MA_push_stack(type,nelem,name,&handle))  MA_get_pointer(handle,&ptr);
        else pnga_error("ga_malloc: MA_push_stack failed",0);
-       addr = (unsigned long)ptr;
+       addr = (size_t)ptr;
     }
     else { /* else, using external memory allocator */
        bytes = nelem*item_size;
-       addr  = (unsigned long)(*ga_ext_alloc)(
+       addr  = (size_t)(*ga_ext_alloc)(
                (size_t)bytes, (int)item_size, name);
     }
 
EOF
patch -p0 -s -N < gamalloc.patch
echo gamalloc.patch applied
