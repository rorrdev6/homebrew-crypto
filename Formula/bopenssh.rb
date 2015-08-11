class Bopenssh < Formula
  desc "OpenBSD freely-licensed SSH connectivity tools"
  homepage "http://www.openssh.com/"
  url "http://ftp.openbsd.org/pub/OpenBSD/OpenSSH/portable/openssh-7.0p1.tar.gz"
  mirror "https://www.mirrorservice.org/pub/OpenBSD/OpenSSH/portable/openssh-7.0p1.tar.gz"
  version "7.0p1"
  sha256 "fd5932493a19f4c81153d812ee4e042b49bbd3b759ab3d9344abecc2bc1485e5"

  depends_on "pkg-config" => :build
  depends_on "libressl" => :recommended
  depends_on "openssl" => :optional
  depends_on "ldns" => :optional

  patch do
    url "https://gist.githubusercontent.com/jacknagel/e4d68a979dca7f968bdb/raw/f07f00f9d5e4eafcba42cc0be44a47b6e1a8dd2a/sandbox.diff"
    sha256 "82c287053eed12ce064f0b180eac2ae995a2b97c6cc38ad1bdd7626016204205"
  end

  # Patch for SSH tunnelling issues caused by launchd changes on Yosemite
  patch do
    url "https://trac.macports.org/export/138238/trunk/dports/net/openssh/files/launchd.patch"
    sha256 "012ee24bf0265dedd5bfd2745cf8262c3240a6d70edcd555e5b35f99ed070590"
  end

  def install
    ENV.append "CPPFLAGS", "-D__APPLE_SANDBOX_NAMED_EXTERNAL__"

    args = %W[
      --with-libedit
      --with-pam
      --with-kerberos5
      --prefix=#{prefix}
      --sysconfdir=#{etc}/ssh
    ]

    args << "--with-ldns" if build.with? "ldns"

    if build.with? "openssl"
      args << "--with-ssl-dir=#{Formula["openssl"].opt_prefix}"
    else
      args << "--with-ssl-dir=#{Formula["libressl"].opt_prefix}"
    end

    args << "--with-ldns" if build.with? "ldns"

    system "./configure", *args
    system "make"
    system "make", "install"
  end
end
