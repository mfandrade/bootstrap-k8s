require 'facter'

Facter.add(:kubectl_latest) do
  setcode do
    Facter::Util::Resolution.exec("curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt")
  end
end
