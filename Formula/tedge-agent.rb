class TedgeAgent < Formula
    desc "thin-edge.io tedge-agent service"
    homepage "https://thin-edge.io/"
    version "0.0.1"
    license "Apache-2.0"
    url "https://thin-edge.io/"
    depends_on "tedge" => :optional
    def install
        # Do nothing
    end
    service do
        name macos: "tedge-agent",
            linux: "tedge-agent"
        run ["#{HOMEBREW_PREFIX}/bin/tedge-agent", "--config-dir", etc/"tedge"]
        keep_alive false
    end
    def caveats
        <<~EOS
            Install tedge-agent service
        EOS
    end
end
