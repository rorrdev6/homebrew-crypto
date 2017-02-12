# NOTE: Configure will fail if using awk 20110810 from dupes.
# Upstream issue: https://savannah.gnu.org/bugs/index.php?37063
class GnuWget < Formula
  desc "Internet file retriever built against LibreSSL"
  homepage "https://www.gnu.org/software/wget/"
  url "https://ftpmirror.gnu.org/wget/wget-1.19.1.tar.xz"
  mirror "https://ftp.gnu.org/gnu/wget/wget-1.19.1.tar.xz"
  sha256 "0c950b9671881222a4d385b013c9604e98a8025d1988529dfca0e93617744cd2"

  head do
    url "git://git.savannah.gnu.org/wget.git"

    depends_on "autoconf" => :build
    depends_on "automake" => :build
    depends_on "xz" => :build
    depends_on "gettext"
  end

  option "with-default-names", "Do not prepend 'l' to the binary"

  depends_on "libressl"
  depends_on "pcre" => :optional
  depends_on "libmetalink" => :optional
  depends_on "gpgme" => :optional

  def install
    args = %W[
      --prefix=#{prefix}
      --sysconfdir=#{etc}
      --with-ssl=openssl
      --with-libssl-prefix=#{Formula["libressl"].opt_prefix}
      --disable-debug
    ]

    args << "--program-prefix=l" if build.without? "default-names"
    args << "--disable-pcre" if build.without? "pcre"
    args << "--with-metalink" if build.with? "libmetalink"
    args << "--with-gpgme-prefix=#{Formula["gpgme"].opt_prefix}" if build.with? "gpgme"

    system "./bootstrap" if build.head?
    system "./configure", *args
    system "make", "install"
    rm_rf share/"info"

    mv "#{man1}/wget.1", "#{man1}/lwget.1" if build.without? "default-names"
  end

  def caveats
    s = ""

    if build.without? "default-names"
      s += <<-EOS.undent
        The binary is prepended with a 'l' so this can be used
        alongside Homebrew's `wget` without conflict.
      EOS
    end

    s
  end

  test do
    system bin/"lwget", "-O", "/dev/null", "https://duckduckgo.com"
  end
end
