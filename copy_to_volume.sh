#!/bin/bash

if (($# != 3))
then
  echo "3 arguments required..."
  echo "  1st : file to transfer"
  echo "  2nd : container name"
  echo "  3rd : volume name"

  exit 1
fi

docker cp $1 $2:$3
