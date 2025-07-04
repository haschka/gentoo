# Copyright 1999-2025 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

DESCRIPTION="Generic build tool with built-in rules for building OCaml library and programs"
HOMEPAGE="https://github.com/ocaml/ocamlbuild"
SRC_URI="https://github.com/ocaml/ocamlbuild/archive/${PV}.tar.gz -> ${P}.tar.gz"

LICENSE="LGPL-2.1-with-linking-exception"
SLOT="0/${PV}"
KEYWORDS="~amd64 ~arm ~arm64 ~hppa ~ppc ~ppc64 ~riscv ~x86 ~amd64-linux ~x86-linux"
IUSE="+ocamlopt"

RDEPEND=">=dev-lang/ocaml-4.02.3-r1:=[ocamlopt?]"
DEPEND="${RDEPEND}
	dev-ml/findlib"

QA_FLAGS_IGNORED='.*'

PATCHES=( "${FILESDIR}"/${PN}-0.15.0-test.patch )

src_prepare() {
	sed -i \
		-e "/package_exists/s:camlp4.macro:xxxxxx:" \
		-e "/package_exists/s:menhirLib:xxxxxx:" \
		testsuite/external.ml || die
	default
}

src_configure() {
	emake -f configure.make Makefile.config \
		PREFIX="${EPREFIX}/usr" \
		BINDIR="${EPREFIX}/usr/bin" \
		LIBDIR="$(ocamlc -where)" \
		OCAML_NATIVE=$(usex ocamlopt true false) \
		OCAML_NATIVE_TOOLS=$(usex ocamlopt true false) \
		NATDYNLINK=$(usex ocamlopt true false)
}

src_compile() {
	emake src/ocamlbuild_config.cmo
	default
}

src_install() {
	# OCaml generates textrels on 32-bit arches
	if use arm || use ppc || use x86 ; then
		export QA_TEXTRELS='.*'
	fi
	emake CHECK_IF_PREINSTALLED=false DESTDIR="${D}" install
	dodoc Changes
}

src_test() {
	emake -j1 test
}
