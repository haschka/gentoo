# Copyright 2022-2025 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

PYTHON_COMPAT=( python3_{10..13} )
ROCM_VERSION=6.1
inherit python-single-r1 cmake cuda flag-o-matic prefix rocm toolchain-funcs

MYPN=pytorch
MYP=${MYPN}-${PV}

DESCRIPTION="A deep learning framework"
HOMEPAGE="https://pytorch.org/"
SRC_URI="https://github.com/pytorch/${MYPN}/archive/refs/tags/v${PV}.tar.gz
	-> ${MYP}.tar.gz
	https://dev.gentoo.org/~tupone/distfiles/${PN}-patches-20240809.tar.gz"

S="${WORKDIR}"/${MYP}

LICENSE="BSD"
SLOT="0"
KEYWORDS="~amd64"
IUSE="cuda distributed fbgemm flash gloo mkl mpi nnpack +numpy onednn openblas opencl openmp qnnpack rocm xnnpack"
RESTRICT="test"
REQUIRED_USE="
	${PYTHON_REQUIRED_USE}
	mpi? ( distributed )
	gloo? ( distributed )
	?? ( cuda rocm )
	rocm? (
		|| ( ${ROCM_REQUIRED_USE} )
		!flash
	)
"

# CUDA 12 not supported yet: https://github.com/pytorch/pytorch/issues/91122
RDEPEND="
	${PYTHON_DEPS}
	dev-cpp/abseil-cpp:=
	dev-cpp/gflags:=
	>=dev-cpp/glog-0.5.0
	dev-libs/cpuinfo
	dev-libs/libfmt:=
	dev-cpp/opentelemetry-cpp
	dev-libs/protobuf:=
	dev-libs/pthreadpool
	dev-libs/sleef[cpu_flags_x86_avx512f(+),cpu_flags_x86_avx(+)]
	dev-libs/sleef[cpu_flags_x86_sse3(+),cpu_flags_x86_ssse3(+)]
	dev-libs/sleef[cpu_flags_x86_sse4_1(+),cpu_flags_x86_sse4_2(+)]
	virtual/lapack
	sci-ml/onnx
	sci-ml/foxi
	cuda? (
		dev-libs/cudnn
		>=sci-ml/cudnn-frontend-1.0.3:0/8
		<dev-util/nvidia-cuda-toolkit-12.5:=[profiler]
	)
	fbgemm? ( sci-ml/FBGEMM )
	gloo? ( sci-ml/gloo[cuda?] )
	mpi? ( virtual/mpi )
	nnpack? ( sci-ml/NNPACK )
	numpy? ( $(python_gen_cond_dep '
		dev-python/numpy[${PYTHON_USEDEP}]
		') )
	onednn? ( sci-ml/oneDNN )
	opencl? ( virtual/opencl )
	qnnpack? (
		!sci-libs/QNNPACK
		sci-ml/gemmlowp
	)
	rocm? (
		=dev-util/hip-6.1*
		=dev-libs/rccl-6.1*
		=sci-libs/rocThrust-6.1*
		=sci-libs/rocPRIM-6.1*
		=sci-libs/hipBLAS-6.1*
		=sci-libs/hipFFT-6.1*
		=sci-libs/hipSPARSE-6.1*
		=sci-libs/hipRAND-6.1*
		=sci-libs/hipCUB-6.1*
		=sci-libs/hipSOLVER-6.1*
		=sci-libs/miopen-6.1*
		=dev-util/roctracer-6.1*

		=sci-libs/hipBLASLt-6.1*
		amdgpu_targets_gfx90a? ( =sci-libs/hipBLASLt-6.1*[amdgpu_targets_gfx90a] )
		amdgpu_targets_gfx940? ( =sci-libs/hipBLASLt-6.1*[amdgpu_targets_gfx940] )
		amdgpu_targets_gfx941? ( =sci-libs/hipBLASLt-6.1*[amdgpu_targets_gfx941] )
		amdgpu_targets_gfx942? ( =sci-libs/hipBLASLt-6.1*[amdgpu_targets_gfx942] )
	)
	distributed? (
		sci-ml/tensorpipe[cuda?]
		dev-cpp/cpp-httplib
	)
	xnnpack? ( sci-ml/XNNPACK )
	mkl? ( sci-libs/mkl )
	openblas? ( sci-libs/openblas )
"
DEPEND="
	${RDEPEND}
	dev-libs/clog
	dev-libs/psimd
	dev-libs/FXdiv
	dev-libs/pocketfft
	dev-libs/flatbuffers
	sci-ml/FP16
	sci-ml/kineto
	$(python_gen_cond_dep '
		dev-python/pybind11[${PYTHON_USEDEP}]
		dev-python/pyyaml[${PYTHON_USEDEP}]
		dev-python/typing-extensions[${PYTHON_USEDEP}]
	')
	cuda? ( <=dev-libs/cutlass-3.4.1 )
	onednn? ( sci-ml/ideep )
"

PATCHES=(
	../patches/${PN}-2.4.0-gentoo.patch
	../patches/${PN}-2.4.0-install-dirs.patch
	../patches/${PN}-1.12.0-glog-0.6.0.patch
	../patches/${PN}-1.13.1-tensorpipe.patch
	../patches/${PN}-2.3.0-cudnn_include_fix.patch
	../patches/${PN}-2.1.2-fix-rpath.patch
	../patches/${PN}-2.4.0-fix-openmp-link.patch
	../patches/${PN}-2.4.0-rocm-fix-std-cpp17.patch
	../patches/${PN}-2.2.2-musl.patch
	../patches/${PN}-2.4.0-exclude-aotriton.patch
	../patches/${PN}-2.3.0-fix-rocm-gcc14-clamp.patch
	../patches/${PN}-2.3.0-fix-libcpp.patch
	"${FILESDIR}"/${PN}-2.4.0-libfmt-11.patch
	"${FILESDIR}"/${PN}-2.4.0-cpp-httplib.patch
	"${FILESDIR}"/${PN}-2.4.0-cstdint.patch
)

src_prepare() {
	filter-lto #bug 862672
	sed -i \
		-e "/third_party\/gloo/d" \
		cmake/Dependencies.cmake \
		|| die
	cmake_src_prepare
	pushd torch/csrc/jit/serialization || die
	flatc --cpp --gen-mutable --scoped-enums mobile_bytecode.fbs || die
	popd
	# prefixify the hardcoded paths, after all patches are applied
	hprefixify \
		aten/CMakeLists.txt \
		caffe2/CMakeLists.txt \
		cmake/Metal.cmake \
		cmake/Modules/*.cmake \
		cmake/Modules_CUDA_fix/FindCUDNN.cmake \
		cmake/Modules_CUDA_fix/upstream/FindCUDA/make2cmake.cmake \
		cmake/Modules_CUDA_fix/upstream/FindPackageHandleStandardArgs.cmake \
		cmake/public/LoadHIP.cmake \
		cmake/public/cuda.cmake \
		cmake/Dependencies.cmake \
		torch/CMakeLists.txt \
		CMakeLists.txt

	if use rocm; then
		sed -e "s:/opt/rocm:/usr:" \
			-e "s:lib/cmake:$(get_libdir)/cmake:g" \
			-e "s/HIP 1.0/HIP 1.0 REQUIRED/" \
			-i cmake/public/LoadHIP.cmake || die

		ebegin "HIPifying cuda sources"
		${EPYTHON} tools/amd_build/build_amd.py || die
		eend $?
	fi
}

src_configure() {
	if use cuda && [[ -z ${TORCH_CUDA_ARCH_LIST} ]]; then
		ewarn "WARNING: caffe2 is being built with its default CUDA compute capabilities: 3.5 and 7.0."
		ewarn "These may not be optimal for your GPU."
		ewarn ""
		ewarn "To configure caffe2 with the CUDA compute capability that is optimal for your GPU,"
		ewarn "set TORCH_CUDA_ARCH_LIST in your make.conf, and re-emerge caffe2."
		ewarn "For example, to use CUDA capability 7.5 & 3.5, add: TORCH_CUDA_ARCH_LIST=7.5 3.5"
		ewarn "For a Maxwell model GPU, an example value would be: TORCH_CUDA_ARCH_LIST=Maxwell"
		ewarn ""
		ewarn "You can look up your GPU's CUDA compute capability at https://developer.nvidia.com/cuda-gpus"
		ewarn "or by running /opt/cuda/extras/demo_suite/deviceQuery | grep 'CUDA Capability'"
	fi

	local mycmakeargs=(
		-DBUILD_CUSTOM_PROTOBUF=OFF
		-DBUILD_SHARED_LIBS=ON

		-DUSE_CCACHE=OFF
		-DUSE_CUDA=$(usex cuda)
		-DUSE_DISTRIBUTED=$(usex distributed)
		-DUSE_MPI=$(usex mpi)
		-DUSE_FAKELOWP=OFF
		-DUSE_FBGEMM=$(usex fbgemm)
		-DUSE_FLASH_ATTENTION=$(usex flash)
		-DUSE_MEM_EFF_ATTENTION=OFF
		-DUSE_GFLAGS=ON
		-DUSE_GLOG=ON
		-DUSE_GLOO=$(usex gloo)
		-DUSE_KINETO=OFF # TODO
		-DUSE_MAGMA=OFF # TODO: In GURU as sci-libs/magma
		-DUSE_MKLDNN=$(usex onednn)
		-DUSE_NNPACK=$(usex nnpack)
		-DUSE_XNNPACK=$(usex xnnpack)
		-DUSE_SYSTEM_XNNPACK=$(usex xnnpack)
		-DUSE_TENSORPIPE=$(usex distributed)
		-DUSE_PYTORCH_QNNPACK=$(usex qnnpack)
		-DUSE_NUMPY=$(usex numpy)
		-DUSE_OPENCL=$(usex opencl)
		-DUSE_OPENMP=$(usex openmp)
		-DUSE_ROCM=$(usex rocm)
		-DUSE_SYSTEM_CPUINFO=ON
		-DUSE_SYSTEM_PYBIND11=ON
		-DUSE_UCC=OFF
		-DUSE_VALGRIND=OFF
		-DPython_EXECUTABLE="${PYTHON}"
		-DUSE_ITT=OFF
		-DUSE_SYSTEM_PTHREADPOOL=ON
		-DUSE_SYSTEM_PSIMD=ON
		-DUSE_SYSTEM_FXDIV=ON
		-DUSE_SYSTEM_FP16=ON
		-DUSE_SYSTEM_GLOO=ON
		-DUSE_SYSTEM_ONNX=ON
		-DUSE_SYSTEM_SLEEF=ON
		-DUSE_PYTORCH_METAL=OFF
		-DUSE_XPU=OFF

		-Wno-dev
		-DTORCH_INSTALL_LIB_DIR="${EPREFIX}"/usr/$(get_libdir)
		-DLIBSHM_INSTALL_LIB_SUBDIR="${EPREFIX}"/usr/$(get_libdir)
	)

	if use mkl; then
		mycmakeargs+=(-DBLAS=MKL)
	elif use openblas; then
		mycmakeargs+=(-DBLAS=OpenBLAS)
	else
		mycmakeargs+=(-DBLAS=Generic -DBLAS_LIBRARIES=)
	fi

	if use cuda; then
		addpredict "/dev/nvidiactl" # bug 867706
		addpredict "/dev/char"
		addpredict "/proc/self/task" # bug 926116

		mycmakeargs+=(
			-DUSE_CUDNN=ON
			-DTORCH_CUDA_ARCH_LIST="${TORCH_CUDA_ARCH_LIST:-3.5 7.0}"
			-DUSE_NCCL=OFF # TODO: NVIDIA Collective Communication Library
			-DCMAKE_CUDA_FLAGS="$(cuda_gccdir -f | tr -d \")"
		)
	elif use rocm; then
		export PYTORCH_ROCM_ARCH="$(get_amdgpu_flags)"

		mycmakeargs+=(
			-DUSE_NCCL=ON
			-DUSE_SYSTEM_NCCL=ON
		)

		# ROCm libraries produce too much warnings
		append-cxxflags -Wno-deprecated-declarations -Wno-unused-result

		if tc-is-clang; then
			# fix mangling in LLVM: https://github.com/llvm/llvm-project/issues/85656
			append-cxxflags -fclang-abi-compat=17
		fi
	fi

	if use onednn; then
		mycmakeargs+=(
			-DUSE_MKLDNN=ON
			-DMKLDNN_FOUND=ON
			-DMKLDNN_LIBRARIES=dnnl
			-DMKLDNN_INCLUDE_DIR="${ESYSROOT}/usr/include/oneapi/dnnl"
		)
	fi

	cmake_src_configure

	# do not rerun cmake and the build process in src_install
	sed '/RERUN/,+1d' -i "${BUILD_DIR}"/build.ninja || die
}

python_install() {
	python_domodule python/caffe2
	python_domodule python/torch
	ln -s ../../../../../include/torch \
		"${D}$(python_get_sitedir)"/torch/include/torch || die # bug 923269
}

src_install() {
	cmake_src_install

	# Used by pytorch ebuild
	insinto "/var/lib/${PN}"
	doins "${BUILD_DIR}"/CMakeCache.txt

	rm -rf python
	mkdir -p python/torch/include || die
	mv "${ED}"/usr/lib/python*/site-packages/caffe2 python/ || die
	cp torch/version.py python/torch/ || die
	python_install
}
