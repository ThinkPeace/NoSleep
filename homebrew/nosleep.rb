class Nosleep < Formula
  desc "macOS no-sleep CLI wrapper around caffeinate"
  homepage "https://github.com/ThinkPeace/NoSleep"
  url "https://github.com/ThinkPeace/NoSleep/releases/download/vX.Y.Z/nosleep-X.Y.Z"
  sha256 "REPLACE_WITH_SHA256"
  version "X.Y.Z"

  def install
    bin.install "nosleep-X.Y.Z" => "nosleep"
  end

  test do
    system "#{bin}/nosleep", "--version"
  end
end
