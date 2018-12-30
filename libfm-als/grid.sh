#!/bin/bash
lambda_list=(4)
d=8
data='avazu-app'
tr='avazu-app.grid.tr.ffm.fm.cvt'
te='avazu-app.grid.va.ffm.fm.cvt'

logs_pth="logs/${data}"

task(){
  for lambda in ${lambda_list[@]} 
  do
	echo "matlab -nodisplay -nosplash -nodesktop -r \"lambda=${lambda};d=${d};tr='${tr}';te='${te}';example;\" > $logs_pth/${tr}.${lambda}.${d}"
  done
}

grid(){
# Empty .task_file.tmp
task > .task_file.tmp

# Create logs_pth
mkdir -p $logs_pth

# Check all command
clear
echo "===All run settings==="
cat .task_file.tmp
echo "====================="

# Number of parameter set do in once.
echo -n "Number of param run at once: "
read num_core
echo "++++++++++++++++++++++++++"

echo -n "Start ? [y/n] "
read std
if [[ $std =~ y ]]
then
  echo "run"
  cat .task_file.tmp | xargs -d '\n' -P $num_core -I {} sh -c {} &
else
  echo "no run"
fi

}

grid
