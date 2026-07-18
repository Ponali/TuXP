sleep 4

echo "STARTCOPYING"

i=0
for name in $(dpkg --get-selections | awk '{print $1}'); do
    ((i++))
    echo "pmstatus:${name//:/}:$i:Configuring $name (amd64)"
    sleep 0.1
    if [ "$i" -eq "100" ]; then
        break
    fi
done

for j in $(seq 0 10); do

echo "PLEASEWAIT $j"
sleep 0.5

done

echo "FINISHED"
sleep 1 # race condition
