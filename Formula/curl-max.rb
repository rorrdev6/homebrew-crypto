class CurlMax < Formula
  desc "Feature-maximised version of cURL, using OpenSSL 1.1"
  homepage "https://curl.haxx.se/"
  url "https://curl.haxx.se/download/curl-7.54.0.tar.bz2"
  mirror "http://curl.askapache.com/download/curl-7.54.0.tar.bz2"
  sha256 "f50ebaf43c507fa7cc32be4b8108fa8bbd0f5022e90794388f3c7694a302ff06"

  keg_only :provided_by_osx

  depends_on "pkg-config" => :build
  depends_on "autoconf" => :build
  depends_on "automake" => :build
  depends_on "libtool" => :build
  depends_on "cunit" => :build
  depends_on "openssl@1.1"
  depends_on "c-ares"
  depends_on "libev"
  depends_on "jansson"
  depends_on "boost"
  depends_on "libmetalink"
  depends_on "libxml2"

  needs :cxx11

  resource "libidn2" do
    url "https://ftp.gnu.org/gnu/libidn/libidn2-2.0.2.tar.gz"
    mirror "https://ftpmirror.gnu.org/libidn/libidn2-2.0.2.tar.gz"
    sha256 "8cd62828b2ab0171e0f35a302f3ad60c3a3fffb45733318b3a8205f9d187eeab"
  end

  # Needed for nghttp2
  resource "libevent" do
    url "https://github.com/libevent/libevent/archive/release-2.1.8-stable.tar.gz"
    sha256 "316ddb401745ac5d222d7c529ef1eada12f58f6376a66c1118eee803cb70f83d"
  end

  # Needed for nghttp2
  resource "spdylay" do
    url "https://github.com/tatsuhiro-t/spdylay/archive/v1.4.0.tar.gz"
    sha256 "31ed26253943b9d898b936945a1c68c48c3e0974b146cef7382320a97d8f0fa0"
  end

  resource "nghttp2" do
    url "https://github.com/nghttp2/nghttp2/releases/download/v1.23.1/nghttp2-1.23.1.tar.xz"
    sha256 "fb75e8c0d6cf9c4381fff242d2dc04cdcc2691af8dc125c6ca349efecf5ccc21"
  end

  resource "libssh2" do
    url "https://libssh2.org/download/libssh2-1.8.0.tar.gz"
    sha256 "39f34e2f6835f4b992cafe8625073a88e5a28ba78f83e8099610a7b3af4676d4"
  end

  def install
    vendor = libexec/"vendor"
    ENV.prepend_path "PKG_CONFIG_PATH", Formula["openssl@1.1"].opt_lib/"pkgconfig"
    ENV.prepend_path "PKG_CONFIG_PATH", vendor/"lib/pkgconfig"
    ENV.prepend_path "PATH", vendor/"bin"
    ENV.cxx11

    resource("libidn2").stage do
      system "./configure", "--disable-dependency-tracking",
                            "--disable-silent-rules",
                            "--prefix=#{vendor}",
                            "--with-packager=Homebrew"
      system "make", "install"
    end

    resource("libevent").stage do
      system "./autogen.sh"
      system "./configure", "--disable-dependency-tracking",
                            "--disable-debug-mode",
                            "--prefix=#{vendor}"
      system "make"
      system "make", "install"
    end

    resource("spdylay").stage do
      if MacOS.version == "10.11" && MacOS::Xcode.installed? &&
         MacOS::Xcode.version >= "8.0"
        ENV["ac_cv_search_clock_gettime"] = "no"
      end

      system "autoreconf", "-fiv"
      system "./configure", "--disable-dependency-tracking",
                            "--prefix=#{vendor}"
      system "make", "install"
    end

    resource("nghttp2").stage do
      system "./configure", "--prefix=#{vendor}",
                            "--disable-silent-rules",
                            "--enable-app",
                            "--with-boost=#{Formula["boost"].opt_prefix}",
                            "--enable-asio-lib",
                            "--with-spdylay",
                            "--disable-python-bindings"
      system "make"
      system "make", "check"
      system "make", "install"
    end

    resource("libssh2").stage do
      system "./configure", "--prefix=#{vendor}",
                            "--disable-debug",
                            "--disable-dependency-tracking",
                            "--disable-silent-rules",
                            "--disable-examples-build",
                            "--with-openssl",
                            "--with-libz",
                            "--with-libssl-prefix=#{Formula["openssl@1.1"].opt_prefix}"
      system "make", "install"
    end

    args = %W[
      --disable-debug
      --disable-dependency-tracking
      --disable-silent-rules
      --prefix=#{prefix}
      --with-libidn2
      --with-ssl=#{Formula["openssl@1.1"].opt_prefix}
      --with-ca-bundle=#{etc}/openssl@1.1/cert.pem
      --with-ca-path=#{etc}/openssl@1.1/certs
      --enable-ares=#{Formula["c-ares"].opt_prefix}
      --with-libssh2
      --without-librtmp
      --with-gssapi
      --with-libmetalink
    ]

    system "./configure", *args
    system "make", "install"
    libexec.install "lib/mk-ca-bundle.pl"
  end

  test do
    # Test vendored libraries.
    (testpath/"test.c").write <<-EOS.undent
      #include <event2/event.h>

      int main()
      {
        struct event_base *base;
        base = event_base_new();
        event_base_free(base);
        return 0;
      }
    EOS
    system ENV.cc, "test.c", "-L#{libexec}/vendor/lib", "-levent", "-o", "test"
    system "./test"

    (testpath/"test2.c").write <<-EOS.undent
      #include <libssh2.h>

      int main(void)
      {
      libssh2_exit();
      return 0;
      }
    EOS

    system ENV.cc, "test2.c", "-L#{libexec}/vendor/lib", "-lssh2", "-o", "test2"
    system "./test2"

    # Test vendored executables.
    system libexec/"vendor/bin/spdycat", "-ns", "https://cloudflare.com/"
    system libexec/"vendor/bin/nghttp", "-nv", "https://nghttp2.org"

    # Test IDN support.
    ENV.delete("LC_CTYPE")
    ENV["LANG"] = "en_US.UTF-8"
    system bin/"curl", "-L", "www.räksmörgås.se", "-o", "index.html"
    assert_predicate testpath/"index.html", :exist?,
                     "Failed to download IDN example site!"
    assert_match "www.xn--rksmrgs-5wao1o.se", File.read("index.html")

    # Fetch the curl tarball and see that the checksum matches.
    # This requires a network connection, but so does Homebrew in general.
    filename = (testpath/"test.tar.gz")
    system bin/"curl", "-L", stable.url, "-o", filename
    filename.verify_checksum stable.checksum

    system libexec/"mk-ca-bundle.pl", "test.pem"
    assert File.exist?("test.pem")
    assert File.exist?("certdata.txt")
  end
end
