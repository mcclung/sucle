(in-package :sandbox)

;;matrix multiplication is associative
 ;;;opengl stored matrices the transpose of sb-cga
(defparameter *camera* nil) ;;global camera
(defparameter vsync? t)

(defparameter *mat4-identity* (cg-matrix:identity-matrix))

(defun render ()
  (declare (optimize (safety 3) (debug 3)))
  (setf (camera-aspect-ratio *camera*) (/ window:*width* window:*height* 1.0))
  (if vsync?
      (window::set-vsync t)
      (window::set-vsync nil))
  (update-matrices *camera*)
  (luse-shader :blockshader)
  (set-overworld-fog *daytime*)

  
  (progn
   (bind-custom-framebuffer *framebuffer*)
   (gl:viewport 0 0 *framebuffer-width* *framebuffer-height*))
  
  (gl:uniform-matrix-4fv
   (gl:get-uniform-location *shader-program* "projectionmodelview")
   *mat4-identity*)
  (bind-shit :font)
  (gl:clear-color 0f0 1f0 0f0 1f0)
  
  (progn
    (gl:clear :color-buffer-bit :depth-buffer-bit)
    (gl:disable :depth-test)
  ;  (lcalllist-invalidate :string)
    (name-mesh :string (lambda ()
			 (gl:with-primitives :quads
			   (draw-string-raster-char foo (floor 256 9) (floor 256 16) 0 32 0.5))))
    (ldrawlist :string))

  (progn
   (gl:uniform-matrix-4fv
    (gl:get-uniform-location *shader-program* "projectionmodelview")
    (camera-matrix-projection-view-player *camera*)
    nil)
   (gl:enable :depth-test)

   (set-sky-color)
   
   (bind-default-framebuffer)
   (gl:viewport 0 0 e:*width* e:*height*)
   (gl:clear :depth-buffer-bit :color-buffer-bit
	     )
   (gl:bind-texture :texture-2d *framebuffer-texture*)
   (ldrawlist :background)
   (progn
    (bind-shit :ocean)
    (gl:enable :cull-face)
    (lcalllist-invalidate :skybox)
    (ldrawlist :skybox)))
  
  
  (window:update-display))

(defun set-sky-color ()
    (let ((r (* *daytime* (aref *sky-color* 0)))
	 (g (* *daytime* (aref *sky-color* 1)))
	 (b (* *daytime* (aref *sky-color* 2))))
     (gl:clear-color r g b 1.0)))
(defparameter *daytime* 0.4)
(defparameter *sky-color* (vector 1.0 0.8 0.68))
(defparameter *fog-ratio* 0.75)
(defun set-overworld-fog (time)
  (flet ((fractionalize (x)
	   (clamp x 0.0 1.0)))
    (let ((x (fractionalize (* (aref *sky-color* 0) time)))
	  (y (fractionalize (* (aref *sky-color* 1) time)))
	  (z (fractionalize (* (aref *sky-color* 2) time))))
      (%gl:uniform-3f (gl:get-uniform-location *shader-program* "fogcolor")
		      x y z)
      (gl:uniformfv (gl:get-uniform-location *shader-program* "cameraPos")
		    (camera-vec-position *camera*))
      (%gl:uniform-1f (gl:get-uniform-location *shader-program* "foglet")
		      (/ -1.0 (camera-frustum-far *camera*) *fog-ratio*))
      (%gl:uniform-1f (gl:get-uniform-location *shader-program* "aratio")
		      (/ 1.0 *fog-ratio*)))))

(defparameter foo
  "
(lambda (x) (* 2 x))
(lambda (x) (print x))
(lambda (x) (* x x))
(lambda (x) (values x x x x))")

(defun glinnit ()
  (setf *camera* (make-camera))
  (setf %gl:*gl-get-proc-address* (e:get-proc-address))
  (setf *shader-program* nil)
  
  (let ((width (if t 480 854))
	(height (if t 360 480)))
    (window:push-dimensions width height))
  (setf e:*resize-hook* #'on-resize)
  
  (setf (values *framebuffer-texture* *framebuffer*)
	(create-framebuffer *framebuffer-width* *framebuffer-height*))
  (bind-custom-framebuffer *framebuffer*)
  (gl:clear-color 0f0 1f0 0f0 1f0)
  (gl:clear :color-buffer-bit)

  (name-funcs)
  (texture-imageries)
  (name-shaders)

  (load-shaders)
  (load-some-images))

(defparameter *framebuffer-width* 512)
(defparameter *framebuffer-height* 512)
(defparameter *framebuffer* nil)
(defparameter *framebuffer-texture* nil)

(defun clean-framebuffers ()
  (gl:delete-framebuffers-ext (list *framebuffer*))
  (gl:delete-textures (list *framebuffer-texture*)))

(defun set-render-cam-pos (camera)
  (let ((vec (camera-vec-position camera))
	(cev (camera-vec-noitisop camera)))
    (setf (aref vec 0) *xpos*)
    (setf (aref vec 1) *ypos*)
    (setf (aref vec 2) *zpos*)

    (setf (aref cev 0) (- *xpos*))
    (setf (aref cev 1) (- *ypos*))
    (setf (aref cev 2) (- *zpos*))

    (unit-pitch-yaw (camera-vec-forward *camera*)
		    (coerce *pitch* 'single-float)
		    (coerce *yaw* 'single-float))
    
    (setf (camera-fov *camera*) defaultfov)))

(defun unit-pitch-yaw (result pitch yaw)
  (let ((cos-pitch (cos pitch)))
    (setf (aref result 0) (* cos-pitch (cos yaw))
	  (aref result 1) (sin pitch)
	  (aref result 2) (* cos-pitch (sin yaw))))
  result)

(defun on-resize (w h)
  (setf *window-height* h
	*window-width* w))

(defparameter dir-resource (merge-pathnames #P"res/" ourdir))
(defparameter dir-shader (merge-pathnames #P"shaders/" dir-resource))

(defun shader-path (name)
  (merge-pathnames name dir-shader))

(defun img-path (name)
  (merge-pathnames name dir-resource))

(defun name-mesh (display-list-name mesh-func)
  (setf (gethash display-list-name *g/call-list-backup*)
	(lambda (&optional name)
	  (declare (ignorable name))
	  (create-call-list-from-func mesh-func))))

(defun texture-imagery (texture-name image-name)
  (setf (gethash texture-name *g/texture-backup*)
	(lambda (&optional name)
	  (declare (ignorable name))
	  (pic-texture (get-image image-name)))))

(defun name-shader (shader-name vs fs attributes)
  (setf (gethash shader-name *g/shader-backup*)
	(lambda (&optional name)
	  (declare (ignorable name))
	  (make-shader-program-from-strings
	   (get-text vs) (get-text fs) attributes))))

(defun src-image (name src-path)
  (setf (gethash name *g/image-backup*)
	(lambda (&optional name)
	  (declare (ignorable name))
	  (let ((img (load-png src-path)))
	    (flip-image img)
	    img))))

;;;;flip an image in-place - three dimensions - does not conse
(defun flip-image (image)
  (let ((dims (array-dimensions image)))
    (let ((height (pop dims))
	  (width (pop dims)))
      (if dims
	  (let ((components (car dims)))
	    (dobox ((h 0 (- height (ash height -1)))
		    (w 0 width)
		    (c 0 components))
		   (rotatef (aref image (- height h 1) w c)
			    (aref image h w c))))
	  (dobox ((h 0 (- height (ash height -1)))
		  (w 0 width))
	      (rotatef (aref image (- height h 1) w)
		       (aref image h w))))))
  image)

(defun src-text (name src-path)
  (setf (gethash name *g/text-backup*)
	(lambda (&optional name)
	  (declare (ignorable name))
	  (file-string src-path))))

(defun load-some-images ()
  (src-image :font-image (img-path #P"font/codepage-437-vga-9x16.png"))
  (src-image :cursor-image (img-path #P"cursor/windos-cursor.png"))
  (src-image :ocean-image (img-path #P"skybox/first-fancy-skybox.png")))

(defun texture-imageries ()
  (texture-imagery :font :font-image)
  (texture-imagery :ocean :ocean-image))
(defun name-shaders ()
  (name-shader :blockshader :bs-vs :bs-frag '(("position" . 0)
					      ("texCoord" . 2)
					      ("darkness" . 8)))
  (name-shader :solidshader :ss-vs :ss-frag '(("position" . 0)
					      ("texCoord" . 2)
					      ("darkness" . 8))))
(defun name-funcs ()
  (name-mesh :background
	     (lambda ()
	       (gl-draw-quads (function draw-background))))
  (name-mesh :skybox (lambda ()
		       (gl-draw-quads (function draw-skybox)))))

(defun gl-draw-quads (func)
  (let ((iter *attrib-buffer-iterators*))
    (reset-attrib-buffer-iterators iter)
    (let ((tex-buf (aref iter 2))
	  (pos-buf (aref iter 0))
	  (lit-buf (aref iter 8)))
      (let ((times (funcall func tex-buf pos-buf lit-buf)))
	(gl:with-primitives :quads
	  (reset-attrib-buffer-iterators iter)
	  (mesh-test42 times lit-buf tex-buf pos-buf))))))

(defun load-shaders ()
  (src-text :bs-vs (shader-path "blockshader/transforms.vs"))
  (src-text :bs-frag (shader-path "blockshader/basictexcoord.frag"))
  (src-text :ss-vs (shader-path "solidshader/transforms.vs"))
  (src-text :ss-frag (shader-path "solidshader/basictexcoord.frag")))

(in-package :sandbox)

(declaim (inline vpc))
(defun vpc (u v x y z)
  (%gl:vertex-attrib-1f 8 1.0)
  (%gl:vertex-attrib-2f 2 u v)
  (%gl:vertex-attrib-3f 0 x y z))
(declaim (notinline vpc))

(eval-always
 (defun duaq (x- x+ y- y+ &optional (start 3) (clockwise-winding nil))
   (if (member start '(1 2 3 4))
       (let ((vec (vector x+ y+
			  x- y+
			  x- y-
			  x+ y-))
	     (i 0)
	     (ii 2)
	     (iii 4)
	     (iv 6))
	 (declare (dynamic-extent vec))
	 (when clockwise-winding
	   (rotatef ii iv))
	 (let ((end-test (* 2 (1- start))))
	   (do ()
	       ((= end-test i)
		(list (aref vec i)
		      (aref vec (1+ i))
		      (aref vec ii)
		      (aref vec (1+ ii))
		      (aref vec iii)
		      (aref vec (1+ iii))
		      (aref vec iv)
		      (aref vec (1+ iv))))
	     (rotatef i ii iii iv))))
       (error "~s is not a plane quadrant" start))))

(eval-always
 (defun aalgnqd (start value subform)
   (if (member start '(0 1 2))
       (let ((places (vector nil nil nil))
	     (count 0))
	 (dolist (form subform)
	   (push form (aref places count))
	   (setf count (- 1 count)))
	 (setf (aref places 2) (list value value value value))
	 (rotatef (aref places 2) (aref places start))
	 (let (acc)
	   (dotimes (x 4)
	     (push (pop (aref places 2)) acc)
	     (push (pop (aref places 1)) acc)
	     (push (pop (aref places 0)) acc))
	   acc))
       (error "~s is not 0 1 or 2" start))))

(defmacro lever (form)
  (eval form))

(fuktard:eval-always
 (progn
   (defun quadi+ (j- j+ k- k+ i)
     (aalgnqd 0 i (duaq j- j+ k- k+ 1 t)))
   (defun quadi- (j- j+ k- k+ i)
     (aalgnqd 0 i (duaq j- j+ k- k+ 3)))
   (defun quadj+ (i- i+ k- k+ j)
     (aalgnqd 1 j (duaq i- i+ k- k+ 1 t)))
   (defun quadj- (i- i+ k- k+  j) 
     (aalgnqd 1 j (duaq i- i+ k- k+ 3)))
   (defun quadk+ (j- j+ i- i+ k)
     (aalgnqd 2 k (duaq i- i+ j- j+ 1)))
   (defun quadk- (j- j+ i- i+ k)
     (aalgnqd 2 k (duaq i- i+ j- j+ 3 t)))

   (defun preach (value form)
     (mapcar (lambda (x)
	       (list value x))
	     form))

   (defun raps (form times)
     (make-list times :initial-element form))))

(defun draw-background (tex-buf pos-buf lit-buf)
  (declare (optimize (safety 0) (speed 3)))
  (declare (type iter-ator:iter-ator tex-buf pos-buf lit-buf))
  (iter-ator:wasabios ((etex tex-buf)
		       (epos pos-buf)
		       (elit lit-buf))
    (let ((distance 0.99999997))
      (loggin (preach 'etex (duaq 0.0 1.0 0.0 1.0 1))
	      (preach 'epos (quadk+ -1.0 1.0 -1.0 1.0 'distance))
	      (preach 'elit (raps 1f0 4)))))
  4)

(defmacro loggin (&rest forms)
  (list (quote lever)
	(list (quote cons)
	      (quote (quote progn))
	      (cons (quote nconc)
		    forms))))

(defun draw-skybox (tex-buf pos-buf lit-buf)
  (declare (optimize (safety 0) (space 3)))
  (declare (type iter-ator:iter-ator tex-buf pos-buf lit-buf))
  (iter-ator:wasabios ((etex tex-buf)
		       (epos pos-buf)
		       (elit lit-buf))
    (let ((h0 0.0)
	  (h1 (/ 1.0 3.0))
	  (h2 (/ 2.0 3.0))
	  (h3 1.0)
	  (w0 0.0)
	  (w1 0.25)
	  (w2 0.5)
	  (w3 0.75)
	  (w4 1.0))
      (let ((neg -10.0)
	    (pos 10.0))
	(loggin (preach 'epos (nconc (quadi+ 'neg 'pos 'neg 'pos 'neg)
				     (quadi- 'neg 'pos 'neg 'pos 'pos)
				     (quadj+ 'neg 'pos 'neg 'pos 'neg)
				     (quadj- 'neg 'pos 'neg 'pos 'pos)
				     (quadk+ 'neg 'pos 'neg 'pos 'neg)
				     (quadk- 'neg 'pos 'neg 'pos 'pos)))
		(preach 'etex (nconc (duaq 'w2 'w3 'h1 'h2  2)
				     (duaq 'w0 'w1 'h1 'h2 3)
				     (duaq 'w1 'w2 'h0 'h1 2)
				     (duaq 'w1 'w2 'h2 'h3 1)
				     (duaq 'w3 'w4 'h1 'h2 1)
				     (duaq 'w1 'w2 'h1 'h2 4)))
		(preach 'elit (raps 1f0 24))))))
  24)

(defconstant +single-float-one-sixteenth+ (coerce 1/16 'single-float))

(defun draw-raster-char-cell (code-point width height x y z)
  (let ((width-unit (/ 1.0 width))
	(height-unit (/ 1.0 height))
	(xstart (- (/ x width) 1.0))
	(ystart (- (/ y height) 1.0)))
    (draw-raster-char code-point xstart	ystart (+ xstart width-unit) (+ ystart height-unit) z)))

(defun draw-raster-char (code-point x1 y1 x2 y2 z)
  (multiple-value-bind (vfoo ufoo) (floor code-point 16)
    (let ((u (/ ufoo 16.0))
	  (v (- 1.0 +single-float-one-sixteenth+ (/ vfoo 16.0))))
      (let ((maxv (+ v +single-float-one-sixteenth+))
	    (maxu (+ u +single-float-one-sixteenth+)))
	(vpc u v x1 y1 z)
	(vpc maxu v x2 y1 z)
	(vpc maxu maxv x2 y2 z)
	(vpc u maxv x1 y2 z)))))

(defun draw-string-raster-char (string width height x y z)
  (let ((xoffset 0)
	(yoffset 0))
    (dotimes (position (length string))
      (let ((char (aref string position)))
	(if (char= char #\Newline)
	    (progn
	      (setf xoffset 0)
	      (decf yoffset))
	    (progn
	      (draw-raster-char-cell (char-code char) width height (+ xoffset x) (+ yoffset y) z)
	      (incf xoffset)))))))

(defparameter +gl-primitives+
  (vector
   :points
   :lines
   :line-strip
   :line-loop
   :triangles
   :triangle-strip
   :triangle-fan
   :quads
   :quad-strip
   :polygon))


