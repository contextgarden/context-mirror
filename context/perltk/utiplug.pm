package utiplug ;

my @data ;
my @result ; 

sub utiplug::initialize 
  { @data = () } 

sub utiplug::process
  { @data = sort @data ;
    for (my $i=0; $i<@data; $i++) 
      { @result[$i] = "\\plugintest\{$i\}\{$data[$i]\}" } }  

sub utiplug::handle     
  { my ($self,$text,$rest) = @_ ; push @data, $text } 

sub utiplug::identify
  { return "utiplug test plugin" }

sub utiplug::report
  { my $keys = @data ; 
    if ($keys) 
      { return ("done", "keys:$keys") }
    else
      { return ("nothing done") } }

sub utiplug::results
  { return @result }

1 ; 
