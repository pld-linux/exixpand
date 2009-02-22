#
%include        /usr/lib/rpm/macros.perl
Summary:	An overlay for Exim string expansion
Summary(pl.UTF-8):	Nakładka na Exima w trybie rozwijania wyrażeń
Name:		exixpand
Version:	20050922.1
Release:	1
License:	GPL v2+
Group:		Applications
# based on http://jetmore.org/john/code/exixpand
Source0:	%{name}.pl
URL:		http://jetmore.org/john/code/#exixpand
BuildRequires:	perl-tools-pod
BuildRequires:	rpm-perlprov
Requires:	exim
Suggests:	perl-perldoc
BuildArch:	noarch
BuildRoot:	%{tmpdir}/%{name}-%{version}-root-%(id -u -n)

%description
An overlay for Exim string expansion testing (exim -be) providing
history, command editing, and macro expansion.

%description -l pl.UTF-8
Nakładka na Exima w trybie testowania rozwijania wyrażeń (exim -be) z
historią, edycją command i rozwijaniem makr.

%prep
%setup -q -c -T

%build
pod2man %SOURCE0 > %{name}.1
pod2text %SOURCE0 > %{name}.txt

%install
rm -rf $RPM_BUILD_ROOT
install -d $RPM_BUILD_ROOT{%{_bindir},%{_mandir}/man1}

install %SOURCE0 $RPM_BUILD_ROOT%{_bindir}/%{name}
install %{name}.1 $RPM_BUILD_ROOT%{_mandir}/man1/%{name}.1

%clean
rm -rf $RPM_BUILD_ROOT

%files
%defattr(644,root,root,755)
%attr(755,root,root) %{_bindir}/%{name}
%{_mandir}/man1/%{name}.1*
%doc %{name}.txt
